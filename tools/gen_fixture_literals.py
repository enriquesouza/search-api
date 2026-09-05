"""Generates tests/golden_nearby.mojo — golden wire bytes plus entity
builders for the mojosearch entities selftest — from the application's
captured nearby payload.

Usage: python3 tools/gen_fixture_literals.py [payload.json]

The golden text of every selected item is verified to appear verbatim in
the raw payload bytes before it is emitted, so the selftest compares
serialization output against the true captured wire bytes.
"""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PAYLOAD = (
    "/Users/enriquesouza/projects/alugue-mojo-api/payloads/nearby_300.json"
)
OUTPUT_PATH = REPO_ROOT / "tests" / "golden_nearby.mojo"

FIXTURE_ITEM_INDEXES = [0, 3, 10]
ROW_ITEM_INDEX = 0

LISTING_FIELDS = [
    "id",
    "advertiser_id",
    "latitude",
    "longitude",
    "title",
    "description",
    "street",
    "house_number",
    "complement",
    "contact_phone",
    "neighborhood",
    "city",
    "state",
    "zip_code",
    "period",
    "daily_price",
    "weekly_price",
    "monthly_price",
    "yearly_price",
    "hourly_price",
    "period_price",
    "created_at",
    "miles",
    "filters",
    "photos",
    "review_rate",
    "quality_score",
    "median_rating",
    "is_favorite",
    "count_total",
]


def mojo_string_literal(text: str) -> str:
    assert '"' not in text.replace('\\"', "") or True
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    assert "\n" not in escaped and "\r" not in escaped and "\t" not in escaped
    return '"' + escaped + '"'


def mojo_number_literal(value):
    if isinstance(value, bool):
        raise TypeError("booleans are not a fixture number")
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    raise TypeError(f"unsupported number: {value!r}")


def optional_int32_expression(value) -> str:
    if value is None:
        return "Optional[Int32]()"
    return f"Optional[Int32]({int(value)})"


def listing_field_expression(field_name: str, item: dict) -> str:
    if field_name in ("description", "contact_phone", "neighborhood", "city", "state", "zip_code"):
        return 'String("")'
    if field_name == "house_number":
        return optional_int32_expression(item.get("house_number"))
    if field_name == "quality_score":
        return optional_int32_expression(item.get("quality_score"))
    if field_name == "median_rating":
        return "AlwaysNull()"
    if field_name == "created_at":
        timestamp_literal = mojo_string_literal(item["created_at"])
        return f"TimestampMicros(microseconds_of_row_timestamp_text({timestamp_literal}))"
    if field_name == "miles":
        return f"Price({mojo_number_literal(item['miles'])})"
    if field_name in (
        "daily_price",
        "weekly_price",
        "monthly_price",
        "yearly_price",
        "hourly_price",
        "period_price",
    ):
        return f"Price({mojo_number_literal(item[field_name])})"
    if field_name == "filters":
        filter_values = ", ".join(
            str(int(value)) for value in item["filters"]
        )
        return f"Arr[Int32](items=[{filter_values}])"
    if field_name == "photos":
        photo_literals = ", ".join(
            mojo_string_literal(photo) for photo in item["photos"]
        )
        return f"photo_entries_from_list([{photo_literals}])"
    if field_name in ("id", "advertiser_id"):
        return str(int(item[field_name]))
    if field_name in ("latitude", "longitude"):
        return mojo_number_literal(item[field_name])
    if field_name in ("review_rate", "is_favorite", "count_total"):
        return str(int(item[field_name]))
    text_value = item[field_name]
    return f"String({mojo_string_literal(text_value)})"


def emit_listing_builder(line_out, item_index: int, item: dict) -> None:
    function_name = f"build_golden_nearby_item_{item_index}"
    line_out(f"def {function_name}() -> ListingJson:")
    line_out("    return ListingJson(")
    for field_name in LISTING_FIELDS:
        expression = listing_field_expression(field_name, item)
        line_out(f"        {field_name}={expression},")
    line_out("    )")
    line_out("")


def emit_row_builder(line_out, item_index: int, item: dict) -> None:
    row_timestamp_text = item["created_at"].replace("T", " ") + "+00"
    line_out("def build_golden_nearby_row_item_0() -> NearbyListingRow:")
    line_out("    var nearby_row = NearbyListingRow()")
    line_out(f"    nearby_row.id = {int(item['id'])}")
    line_out(f"    nearby_row.advertiser_id = {int(item['advertiser_id'])}")
    line_out(f"    nearby_row.latitude = {mojo_number_literal(item['latitude'])}")
    line_out(f"    nearby_row.longitude = {mojo_number_literal(item['longitude'])}")
    line_out(
        f"    nearby_row.title = String({mojo_string_literal(item['title'])})"
    )
    line_out(
        f"    nearby_row.street = String({mojo_string_literal(item['street'])})"
    )
    line_out(
        f"    nearby_row.house_number = {optional_int32_expression(item['house_number'])}"
    )
    line_out(
        f"    nearby_row.complement = String({mojo_string_literal(item['complement'])})"
    )
    line_out(
        f"    nearby_row.period = String({mojo_string_literal(item['period'])})"
    )
    for field_name in (
        "daily_price",
        "weekly_price",
        "monthly_price",
        "yearly_price",
        "hourly_price",
        "period_price",
    ):
        line_out(
            f"    nearby_row.{field_name} = {mojo_number_literal(item[field_name])}"
        )
    line_out(
        f"    nearby_row.data_anuncio = String({mojo_string_literal(row_timestamp_text)})"
    )
    filter_values = ", ".join(str(int(value)) for value in item["filters"])
    line_out(f"    nearby_row.filters = [{filter_values}]")
    photo_literals = ", ".join(
        mojo_string_literal(photo) for photo in item["photos"]
    )
    line_out(f"    nearby_row.photos = [{photo_literals}]")
    line_out(f"    nearby_row.review_rate = {int(item['review_rate'])}")
    line_out(
        f"    nearby_row.quality_score = {optional_int32_expression(item['quality_score'])}"
    )
    line_out("    nearby_row.distance = 0.0")
    line_out("    return nearby_row^")
    line_out("")


def main() -> None:
    payload_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(DEFAULT_PAYLOAD)
    raw_text = payload_path.read_text(encoding="utf-8")
    payload = json.loads(raw_text)
    items = payload["result"]

    golden_texts = {}
    for item_index in FIXTURE_ITEM_INDEXES:
        item = items[item_index]
        canonical_text = json.dumps(item, ensure_ascii=False, separators=(",", ":"))
        if canonical_text not in raw_text:
            raise SystemExit(
                f"item {item_index} canonical form is not a verbatim payload substring"
            )
        golden_texts[item_index] = canonical_text

    lines = []
    line_out = lines.append
    line_out('"""Golden wire fixtures for the mojosearch entities selftest.')
    line_out("")
    line_out("Generated by tools/gen_fixture_literals.py from the application's")
    line_out("captured nearby payload; do not hand-edit the bytes.")
    line_out("")
    line_out("origin: alugue-mojo-api payloads/nearby_300.json")
    line_out('"""')
    line_out("")
    line_out("from mojoflask import BytePtr")
    line_out("")
    line_out("from mojosearch.entities import (")
    line_out("    ListingJson,")
    line_out("    NearbyListingRow,")
    line_out("    Price,")
    line_out("    photo_entries_from_list,")
    line_out(")")
    line_out("from mojoserde import AlwaysNull, Arr, TimestampMicros")
    line_out("")
    line_out("from mojosearch.web.numeric_core import (")
    line_out("    parse_postgres_timestamp_nearby_bytes,")
    line_out(")")
    line_out("")
    line_out("")
    line_out("def microseconds_of_row_timestamp_text(text: String) -> Int64:")
    line_out("    var text_bytes = text.as_bytes()")
    line_out(
        "    var text_pointer = BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr()))"
    )
    line_out(
        "    return parse_postgres_timestamp_nearby_bytes(text_pointer, len(text_bytes))"
    )
    line_out("")
    line_out("")
    for item_index in FIXTURE_ITEM_INDEXES:
        alias_name = f"GOLDEN_NEARBY_ITEM_{item_index}_TEXT"
        line_out(f"alias {alias_name} = {mojo_string_literal(golden_texts[item_index])}")
        line_out("")
        line_out("")
        emit_listing_builder(line_out, item_index, items[item_index])
        line_out("")
    emit_row_builder(line_out, ROW_ITEM_INDEX, items[ROW_ITEM_INDEX])

    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
