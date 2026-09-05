from mojoflask import (
    BytePtr,
    free_bytes,
    malloc_bytes,
    read_file_into,
)

from emberjson import Value, try_parse

from mojoserde import Arr, AlwaysNull, TimestampMicros

from mojosearch.entities import (
    ListingJson,
    Price,
    photo_entries_from_list,
)

from mojosearch.web.binding import MAX_LIMIT

from mojosearch.web.nearby_writer import build_nearby_envelope_exact

from mojosearch.web.numeric_core import parse_postgres_timestamp_nearby_bytes


comptime PAYLOAD_CAPACITY = 1 << 19

comptime PAYLOAD_PATH = "mojosearch/web/tests/payloads/nearby_300.json"


def fail(detail: String) raises -> None:

    raise Error("envelope golden probe failed: " + detail)


def object_has_key(ref object_value: Value, key_name: String) raises -> Bool:

    for key in object_value.object():
        if String(key) == key_name:
            return True
    return False


def optional_int32_of(ref value: Value) raises -> Optional[Int32]:

    if value.is_null():
        return Optional[Int32]()
    return Int32(value.int())


def string_bytes_pointer_of(imm text: String) -> BytePtr:

    var text_bytes = text.as_bytes()
    return BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr()))


def listing_json_of(ref item_value: Value) raises -> ListingJson:

    var created_at_text = String(item_value["created_at"].string())
    var created_at_bytes = created_at_text.as_bytes()
    var photo_texts = List[String]()
    ref photos_value = item_value["photos"]
    if not photos_value.is_null():
        ref photos_array = photos_value.array()
        for photo_index in range(len(photos_array)):
            photo_texts.append(String(photos_array[photo_index].string()))
    var filter_ids = List[Int32]()
    ref filters_value = item_value["filters"]
    if not filters_value.is_null():
        ref filters_array = filters_value.array()
        for filter_index in range(len(filters_array)):
            filter_ids.append(Int32(filters_array[filter_index].int()))
    return ListingJson(
        id=item_value["id"].int(),
        advertiser_id=item_value["advertiser_id"].int(),
        latitude=Float64(item_value["latitude"].float()),
        longitude=Float64(item_value["longitude"].float()),
        title=String(item_value["title"].string()),
        description=String(item_value["description"].string()),
        street=String(item_value["street"].string()),
        house_number=optional_int32_of(item_value["house_number"]),
        complement=String(item_value["complement"].string()),
        contact_phone=String(item_value["contact_phone"].string()),
        neighborhood=String(""),
        city=String(""),
        state=String(""),
        zip_code=String(""),
        period=String(item_value["period"].string()),
        daily_price=Price(Float64(item_value["daily_price"].float())),
        weekly_price=Price(Float64(item_value["weekly_price"].float())),
        monthly_price=Price(Float64(item_value["monthly_price"].float())),
        yearly_price=Price(Float64(item_value["yearly_price"].float())),
        hourly_price=Price(Float64(item_value["hourly_price"].float())),
        period_price=Price(Float64(item_value["period_price"].float())),
        created_at=TimestampMicros(
            parse_postgres_timestamp_nearby_bytes(
                string_bytes_pointer_of(created_at_text),
                len(created_at_bytes),
            )
        ),
        miles=Price(Float64(item_value["miles"].float())),
        filters=Arr[Int32](items=filter_ids^),
        photos=photo_entries_from_list(photo_texts^),
        review_rate=Int32(item_value["review_rate"].int()),
        quality_score=(
            optional_int32_of(item_value["quality_score"])
            if object_has_key(item_value, "quality_score")
            else Optional[Int32]()
        ),
        median_rating=AlwaysNull(),
        is_favorite=Int32(item_value["is_favorite"].int()),
        count_total=Int32(item_value["count_total"].int()),
    )


def main() raises:

    var payload_bytes = malloc_bytes(PAYLOAD_CAPACITY)
    var payload_length = read_file_into(PAYLOAD_PATH, payload_bytes, PAYLOAD_CAPACITY)
    if payload_length <= 0:
        fail("payload file unreadable at " + PAYLOAD_PATH)
    var payload_text = String(
        unsafe_from_utf8=Span[Byte](
            unsafe_ptr=payload_bytes, length=payload_length
        )
    )
    var parsed_payload = try_parse(payload_text)
    if not parsed_payload:
        fail("payload does not parse")
    ref payload_root = parsed_payload.value()

    var decoded_rows = List[ListingJson]()
    ref result_array = payload_root["result"].array()
    for row_index in range(len(result_array)):
        decoded_rows.append(listing_json_of(result_array[row_index]))

    var decoded_row_count = len(decoded_rows)
    var expected_count_total = Int(payload_root["count_total"].int())
    if payload_root["has_more"].bool():
        fail("payload golden expected has_more false")
    if decoded_row_count == 0:
        fail("payload golden decoded zero rows")

    var built_envelope = build_nearby_envelope_exact(
        decoded_rows^, 0, MAX_LIMIT, True, expected_count_total, True
    )
    var built_pointer = built_envelope[0]
    var built_length = built_envelope[1]

    if built_length != payload_length:
        fail(
            "built length "
            + String(built_length)
            + " differs from payload length "
            + String(payload_length)
        )
    var first_difference = -1
    var byte_index = 0
    while byte_index < payload_length:
        if built_pointer[byte_index] != payload_bytes[byte_index]:
            first_difference = byte_index
            break
        byte_index += 1
    if first_difference != -1:
        fail(
            "built envelope differs from payload at byte "
            + String(first_difference)
        )

    free_bytes(payload_bytes)
    free_bytes(built_pointer)
    var report = String("envelope golden selftest: ALL PASS (")
    report += String(decoded_row_count)
    report += " rows round-tripped byte-exact)"
    print(report)
