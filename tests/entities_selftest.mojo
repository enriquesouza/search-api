"""Mojosearch entities selftest — golden wire bytes from the application's
captured nearby payload.

Run: pixi run run-entities-selftest

Note: tests/selftest.mojo is the shared entrypoint owned by the queries
wave; these entity wire proofs land beside it until final wiring merges
them.
"""

from mojoserde import ByteBuf, serialize_into

from mojosearch import (
    FilterNodeJson,
    GroupedChildLocalizedJson,
    PhotoEntries,
    Price,
    listing_json_from_nearby_row,
    photo_entries_from_list,
)

from tests.golden_nearby import (
    GOLDEN_NEARBY_ITEM_0_TEXT,
    GOLDEN_NEARBY_ITEM_10_TEXT,
    GOLDEN_NEARBY_ITEM_3_TEXT,
    build_golden_nearby_item_0,
    build_golden_nearby_item_10,
    build_golden_nearby_item_3,
    build_golden_nearby_row_item_0,
)


def serialize_entity_to_text[T: AnyType](ref entity: T) -> String:
    var wire_buffer = ByteBuf(1 << 16)
    serialize_into(entity, wire_buffer)
    return wire_buffer.to_string()


def wire_text_of_photo_entries(imm photo_entries: PhotoEntries) -> String:
    var wire_buffer = ByteBuf(256)
    photo_entries.write_wire(wire_buffer)
    return wire_buffer.to_string()


def wire_text_of_price(imm price_value: Price) -> String:
    var wire_buffer = ByteBuf(64)
    price_value.write_wire(wire_buffer)
    return wire_buffer.to_string()


def report_wire_mismatch(
    section_name: String, expected_wire_text: String, actual_wire_text: String
) -> Bool:
    print("FAIL", section_name)
    print("  expected byte length:", expected_wire_text.byte_length())
    print("  actual byte length:  ", actual_wire_text.byte_length())
    return False


def check_listing_json_golden_bytes(
    section_name: String, expected_wire_text: String, actual_wire_text: String
) -> Bool:
    if actual_wire_text == expected_wire_text:
        return True
    return report_wire_mismatch(
        section_name, expected_wire_text, actual_wire_text
    )


def check_listing_json_items_against_golden() -> Bool:
    var item_0_matches = check_listing_json_golden_bytes(
        "listing_json_item_0",
        GOLDEN_NEARBY_ITEM_0_TEXT,
        serialize_entity_to_text(build_golden_nearby_item_0()),
    )
    var item_3_matches = check_listing_json_golden_bytes(
        "listing_json_item_3",
        GOLDEN_NEARBY_ITEM_3_TEXT,
        serialize_entity_to_text(build_golden_nearby_item_3()),
    )
    var item_10_matches = check_listing_json_golden_bytes(
        "listing_json_item_10",
        GOLDEN_NEARBY_ITEM_10_TEXT,
        serialize_entity_to_text(build_golden_nearby_item_10()),
    )
    return item_0_matches and item_3_matches and item_10_matches


def check_row_conversion_against_golden() -> Bool:
    var nearby_row = build_golden_nearby_row_item_0()
    var converted_listing = listing_json_from_nearby_row(nearby_row, True)
    return check_listing_json_golden_bytes(
        "row_conversion_item_0",
        GOLDEN_NEARBY_ITEM_0_TEXT,
        serialize_entity_to_text(converted_listing),
    )


def check_row_conversion_without_geo() -> Bool:
    var nearby_row = build_golden_nearby_row_item_0()
    var converted_listing = listing_json_from_nearby_row(nearby_row, False)
    if converted_listing.miles.amount != -1.0:
        print("FAIL row_conversion_without_geo: miles should be -1.0")
        return False
    if converted_listing.id != nearby_row.id:
        print("FAIL row_conversion_without_geo: id should carry over")
        return False
    return True


def check_photo_entries_ordinal_transform() -> Bool:
    var marked_entries = photo_entries_from_list(
        ["3_c.png", "1_a.png"]
    )
    var expected_wire_text = String("[\"a.png\",\"c.png\"]")
    if wire_text_of_photo_entries(marked_entries) != expected_wire_text:
        print("FAIL photo_entries_ordinal_transform")
        return False
    return True


def check_price_compact_wire() -> Bool:
    if wire_text_of_price(Price(0.0)) != String("0.0"):
        print("FAIL price_compact_wire: 0.0")
        return False
    if wire_text_of_price(Price(-1.0)) != String("-1.0"):
        print("FAIL price_compact_wire: -1.0")
        return False
    if wire_text_of_price(Price(55.0)) != String("55.0"):
        print("FAIL price_compact_wire: 55.0")
        return False
    if wire_text_of_price(Price(0.001493694039310427)) != String(
        "0.001493694039310427"
    ):
        print("FAIL price_compact_wire: long decimal")
        return False
    return True


def check_taxonomy_wire_structs() -> Bool:
    var filter_node = FilterNodeJson(
        id=7,
        name=String("Festas"),
        parent_filter_id=Optional[Int64](),
        name_en=Optional[String]("Parties"),
        name_es=Optional[String](),
    )
    var expected_filter_node_wire_text = String(
        "{\"id\":7,\"name\":\"Festas\",\"parent_filter_id\":null,"
        + "\"name_en\":\"Parties\",\"name_es\":null}"
    )
    if serialize_entity_to_text(filter_node) != expected_filter_node_wire_text:
        print("FAIL taxonomy_wire_structs: FilterNodeJson")
        return False
    var grouped_child = GroupedChildLocalizedJson(
        id=3, listing_count=12, name=String("Festas")
    )
    var expected_grouped_child_wire_text = String(
        "{\"id\":3,\"listing_count\":12,\"name\":\"Festas\"}"
    )
    if serialize_entity_to_text(grouped_child) != expected_grouped_child_wire_text:
        print("FAIL taxonomy_wire_structs: GroupedChildLocalizedJson")
        return False
    return True


def main() raises:
    var passed_section_count = 0
    var total_section_count = 6
    if check_listing_json_items_against_golden():
        passed_section_count += 1
    if check_row_conversion_against_golden():
        passed_section_count += 1
    if check_row_conversion_without_geo():
        passed_section_count += 1
    if check_photo_entries_ordinal_transform():
        passed_section_count += 1
    if check_price_compact_wire():
        passed_section_count += 1
    if check_taxonomy_wire_structs():
        passed_section_count += 1
    print("sections passed:", passed_section_count, "of", total_section_count)
    if passed_section_count != total_section_count:
        raise Error("mojosearch entities selftest FAILED")
    print("ALL MOJOSEARCH ENTITY SELFTEST SECTIONS GREEN")
