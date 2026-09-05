from mojoflask import BytePtr

from mojosearch.services.taxonomy_render import (
    build_taxonomy_tree,
    language_code_from_path_segment,
    parse_tagged_language_prefix,
    render_flat_taxonomy_json,
    render_grouped_taxonomy_json,
    resolve_page_language,
)

from mojosearch.services.taxonomy_state import (
    LANG_EN,
    LANG_ES,
    LANG_PT,
    Taxonomy,
)

from mojosearch.repositories.filter_repository import FilterNode


comptime GOLDEN_FLAT = "[{\"id\":1,\"name\":\"Praias\",\"parent_filter_id\":null,\"name_en\":\"Beaches\",\"name_es\":\"Playas\"},{\"id\":2,\"name\":\"Praia Grande\",\"parent_filter_id\":1,\"name_en\":\"Grand Beach\",\"name_es\":\"Playa Grande\"},{\"id\":3,\"name\":\"Piscinas\",\"parent_filter_id\":null,\"name_en\":\"Pools\",\"name_es\":\"Piscinas\"},{\"id\":4,\"name\":\"Piscina Aquecida\",\"parent_filter_id\":3,\"name_en\":\"Heated Pool\",\"name_es\":\"Piscina Caliente\"},{\"id\":5,\"name\":\"Orfa\",\"parent_filter_id\":99,\"name_en\":\"Orphan\",\"name_es\":\"Huerfana\"}]"

comptime GOLDEN_GROUPED = "{\"beaches\":[{\"id\":2,\"listing_count\":10,\"name\":\"Praia Grande\",\"name_en\":\"Grand Beach\",\"name_es\":\"Playa Grande\"}],\"pools\":[{\"id\":4,\"listing_count\":3,\"name\":\"Piscina Aquecida\",\"name_en\":\"Heated Pool\",\"name_es\":\"Piscina Caliente\"}]}"

comptime GOLDEN_FLAT_PT = "[{\"id\":1,\"name\":\"Praias\",\"parent_filter_id\":null},{\"id\":2,\"name\":\"Praia Grande\",\"parent_filter_id\":1},{\"id\":3,\"name\":\"Piscinas\",\"parent_filter_id\":null},{\"id\":4,\"name\":\"Piscina Aquecida\",\"parent_filter_id\":3},{\"id\":5,\"name\":\"Orfa\",\"parent_filter_id\":99}]"

comptime GOLDEN_FLAT_ES = "[{\"id\":1,\"name\":\"Playas\",\"parent_filter_id\":null},{\"id\":2,\"name\":\"Playa Grande\",\"parent_filter_id\":1},{\"id\":3,\"name\":\"Piscinas\",\"parent_filter_id\":null},{\"id\":4,\"name\":\"Piscina Caliente\",\"parent_filter_id\":3},{\"id\":5,\"name\":\"Huerfana\",\"parent_filter_id\":99}]"

comptime GOLDEN_FLAT_EN = "[{\"id\":1,\"name\":\"Beaches\",\"parent_filter_id\":null},{\"id\":2,\"name\":\"Grand Beach\",\"parent_filter_id\":1},{\"id\":3,\"name\":\"Pools\",\"parent_filter_id\":null},{\"id\":4,\"name\":\"Heated Pool\",\"parent_filter_id\":3},{\"id\":5,\"name\":\"Orphan\",\"parent_filter_id\":99}]"

comptime GOLDEN_GROUPED_PT = "{\"beaches\":[{\"id\":2,\"listing_count\":10,\"name\":\"Praia Grande\"}],\"pools\":[{\"id\":4,\"listing_count\":3,\"name\":\"Piscina Aquecida\"}]}"

comptime GOLDEN_GROUPED_ES = "{\"beaches\":[{\"id\":2,\"listing_count\":10,\"name\":\"Playa Grande\"}],\"pools\":[{\"id\":4,\"listing_count\":3,\"name\":\"Piscina Caliente\"}]}"

comptime GOLDEN_GROUPED_EN = "{\"beaches\":[{\"id\":2,\"listing_count\":10,\"name\":\"Grand Beach\"}],\"pools\":[{\"id\":4,\"listing_count\":3,\"name\":\"Heated Pool\"}]}"


def strings_match(text: String, expected: StaticString) -> Bool:
    var text_bytes = text.as_bytes()
    var expected_bytes = expected.as_bytes()
    if len(text_bytes) != len(expected_bytes):
        return False
    var byte_index = 0
    while byte_index < len(expected_bytes):
        if text_bytes[byte_index] != expected_bytes[byte_index]:
            return False
        byte_index += 1
    return True


def stored_bytes_match(
    body_pointer: BytePtr, body_length: Int, expected: StaticString
) -> Bool:
    var expected_bytes = expected.as_bytes()
    if body_length != len(expected_bytes):
        return False
    var byte_index = 0
    while byte_index < body_length:
        if Int(body_pointer[unsafe_offset=byte_index]) != Int(
            expected_bytes[byte_index]
        ):
            return False
        byte_index += 1
    return True


def make_node(
    node_id: Int64,
    name: String,
    name_en: String,
    name_es: String,
    parent_id: Int64,
    has_parent: Bool,
) -> FilterNode:
    return FilterNode(
        id=node_id,
        name=name,
        name_en=name_en,
        name_es=name_es,
        parent=parent_id,
        has_parent=has_parent,
        has_name_en=True,
        has_name_es=True,
        is_active=True,
    )


def build_synthetic_taxonomy() -> Taxonomy:
    var taxonomy = Taxonomy()
    taxonomy.nodes.append(
        make_node(1, "Praias", "Beaches", "Playas", 0, False)
    )
    taxonomy.nodes.append(
        make_node(2, "Praia Grande", "Grand Beach", "Playa Grande", 1, True)
    )
    taxonomy.nodes.append(
        make_node(3, "Piscinas", "Pools", "Piscinas", 0, False)
    )
    taxonomy.nodes.append(
        make_node(4, "Piscina Aquecida", "Heated Pool", "Piscina Caliente", 3, True)
    )
    taxonomy.nodes.append(
        make_node(5, "Orfa", "Orphan", "Huerfana", 99, True)
    )
    taxonomy.counts[2] = 10
    taxonomy.counts[4] = 3
    taxonomy.counts[5] = 7
    return taxonomy^


def fail(message: StaticString) raises:
    raise Error("SELFTEST FAIL: " + message)


def main() raises:
    print("[1] language resolution helpers")
    if language_code_from_path_segment("br") != LANG_PT:
        fail("path segment 'br' must resolve to LANG_PT")
    if language_code_from_path_segment(" us ") != LANG_EN:
        fail("path segment ' us ' must fold and resolve to LANG_EN")
    if language_code_from_path_segment("es") != LANG_ES:
        fail("path segment 'es' must resolve to LANG_ES")
    var tagged = parse_tagged_language_prefix("pt-BR")
    if not tagged.was_recognized or tagged.language_index != LANG_PT:
        fail("tagged prefix 'pt-BR' must resolve to LANG_PT")
    if resolve_page_language("en-US", "br") != LANG_EN:
        fail("a recognized tag must win over the path segment")
    if resolve_page_language("fr", "br") != LANG_PT:
        fail("an unrecognized tag must fall through to the path segment")

    print("[2] build_taxonomy_tree renders all eight prebuilt bodies")
    var taxonomy = build_synthetic_taxonomy()
    build_taxonomy_tree(taxonomy)

    if not strings_match(taxonomy.flat_json, GOLDEN_FLAT):
        fail("legacy flat render drifted from the golden bytes")
    if not strings_match(taxonomy.grouped_json, GOLDEN_GROUPED):
        fail("legacy grouped render drifted from the golden bytes")
    if not strings_match(taxonomy.flat_by_lang[LANG_PT], GOLDEN_FLAT_PT):
        fail("pt flat render drifted from the golden bytes")
    if not strings_match(taxonomy.flat_by_lang[LANG_ES], GOLDEN_FLAT_ES):
        fail("es flat render drifted from the golden bytes")
    if not strings_match(taxonomy.flat_by_lang[LANG_EN], GOLDEN_FLAT_EN):
        fail("en flat render drifted from the golden bytes")
    if not strings_match(taxonomy.grouped_by_lang[LANG_PT], GOLDEN_GROUPED_PT):
        fail("pt grouped render drifted from the golden bytes")
    if not strings_match(taxonomy.grouped_by_lang[LANG_ES], GOLDEN_GROUPED_ES):
        fail("es grouped render drifted from the golden bytes")
    if not strings_match(taxonomy.grouped_by_lang[LANG_EN], GOLDEN_GROUPED_EN):
        fail("en grouped render drifted from the golden bytes")

    print("[3] prebuilt body readers return the same bytes per path segment")
    var flat_br = render_flat_taxonomy_json(taxonomy, "br")
    if not stored_bytes_match(flat_br[0], flat_br[1], GOLDEN_FLAT_PT):
        fail("flat 'br' reader must serve the pt body bytes")
    var flat_us = render_flat_taxonomy_json(taxonomy, "us")
    if not stored_bytes_match(flat_us[0], flat_us[1], GOLDEN_FLAT_EN):
        fail("flat 'us' reader must serve the en body bytes")
    var grouped_xx = render_grouped_taxonomy_json(taxonomy, "xx")
    if not stored_bytes_match(grouped_xx[0], grouped_xx[1], GOLDEN_GROUPED_ES):
        fail("grouped 'xx' reader must fall through to the es body bytes")

    print("taxonomy_render_test: ALL PASS")
