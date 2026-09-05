"""mojosearch.web.nearby_writer — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby_response_writer.mojo
"""

from mojoflask import free_bytes

from mojolinq import map_elements

from mojosearch.entities import (
    DetailsJson,
    ListingJson,
    NearbyListingRow,
    OkResponseWrapperJson,
    listing_json_from_nearby_row,
)
from mojoserde import AlwaysNull, Arr, serialize_into
from mojoserde.buf import ByteBuf, BytePtr, retracked

from pqmojo.timestamp import civil_from_days
from mojoflask.text import utf8_rune_at


def listing_jsons_from_nearby_rows(
    imm rows: List[NearbyListingRow], has_geo: Bool
) -> List[ListingJson]:
    def nearby_row_to_listing_json(
        row: NearbyListingRow,
    ) {has_geo} -> ListingJson:
        return listing_json_from_nearby_row(row, has_geo)

    return map_elements(rows, nearby_row_to_listing_json)


def build_nearby_envelope(
    var rows: List[ListingJson],
    skip: Int,
    limit: Int,
    has_geo: Bool,
    max_results: Int,
) -> Tuple[BytePtr, Int]:
    return build_nearby_envelope_exact(
        rows^, skip, limit, has_geo, max_results, True
    )


def build_nearby_envelope_exact(
    var rows: List[ListingJson],
    skip: Int,
    limit: Int,
    has_geo: Bool,
    max_results: Int,
    resort_by_miles: Bool,
) -> Tuple[BytePtr, Int]:

    var total = len(rows)
    var start = min(skip, total)
    var end = min(start + limit, total)

    var order = List[Int]()
    var running_index = start
    while running_index < end:
        order.append(running_index)
        running_index += 1
    if has_geo and resort_by_miles:
        var insert_position = 1
        while insert_position < len(order):
            var current_index = order[insert_position]
            var current_miles = rows[current_index].miles.amount
            var current_id = rows[current_index].id
            var compare_position = insert_position - 1
            while compare_position >= 0:
                var compare_index = order[compare_position]
                var compare_miles = rows[compare_index].miles.amount
                if compare_miles > current_miles or (
                    compare_miles == current_miles
                    and rows[compare_index].id > current_id
                ):
                    order[compare_position + 1] = compare_index
                    compare_position -= 1
                else:
                    break
            order[compare_position + 1] = current_index
            insert_position += 1

    var page_items = List[ListingJson](capacity=len(order))
    var page_index = 0
    while page_index < len(order):
        page_items.append(rows[order[page_index]].copy())
        page_index += 1

    var page = OkResponseWrapperJson[Arr[ListingJson]](
        error_message=AlwaysNull(),
        result=Arr[ListingJson](items=page_items^),
        has_more=total > end,
        count_total=Int64(max_results),
        save_changes_result=0,
        type=String(""),
    )
    var serialized_page = ByteBuf(total * 1024 + 128)
    serialize_into(page, serialized_page)
    return (retracked(serialized_page.ptr), serialized_page.size)


def build_details_envelope(var row: DetailsJson) -> Tuple[BytePtr, Int]:

    var items = List[DetailsJson](capacity=1)
    items.append(row^)
    var page = OkResponseWrapperJson[Arr[DetailsJson]](
        error_message=AlwaysNull(),
        result=Arr[DetailsJson](items=items^),
        has_more=False,
        count_total=1,
        save_changes_result=0,
        type=String(""),
    )
    var serialized_page = ByteBuf(4096)
    serialize_into(page, serialized_page)
    return (retracked(serialized_page.ptr), serialized_page.size)
