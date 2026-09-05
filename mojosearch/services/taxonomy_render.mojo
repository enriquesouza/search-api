from mojoflask import BytePtr

from mojoflask.text import (
    has_visible_content,
    lowercase_ascii_letters_only,
    trim_space_tab_newline_carriage_return_around,
)

from mojolinq import (
    filter,
    for_each,
    fold_into,
    group_by,
    map_elements,
    sort_by,
)

from mojoserde import (
    Arr,
    serialize_into,
    ByteBuf as SerdeByteBuf,
    emit_escaped_json_string,
    optional_when,
)

from mojosearch.entities.taxonomy_wire import (
    FilterNodeJson,
    GroupedChildJson,
    GroupedChildLocalizedJson,
    LocalizedFilterJson,
)

from mojosearch.repositories.filter_repository import FilterNode

from mojosearch.services.taxonomy_state import LANG_EN, LANG_ES, LANG_PT, Taxonomy


def _pick_localized_name_for_language(
    imm filter_node: FilterNode,
    language: Int,
) -> String:

    if (
        language == LANG_EN
        and filter_node.has_name_en
        and has_visible_content(filter_node.name_en)
    ):
        return filter_node.name_en
    if (
        language == LANG_ES
        and filter_node.has_name_es
        and has_visible_content(filter_node.name_es)
    ):
        return filter_node.name_es
    return filter_node.name


def _trim_language_tag_whitespace(text: String) -> String:

    return trim_space_tab_newline_carriage_return_around(text)


def language_code_from_path_segment(segment: String) -> Int:

    var folded_segment = lowercase_ascii_letters_only(
        _trim_language_tag_whitespace(segment)
    )
    if folded_segment == "br":
        return LANG_PT
    if folded_segment == "us":
        return LANG_EN
    return LANG_ES


@fieldwise_init
struct ResolvedTaggedLanguage(Copyable, Movable):

    var was_recognized: Bool
    var language_index: Int


def parse_tagged_language_prefix(code: String) -> ResolvedTaggedLanguage:

    var primary_subtag = _trim_language_tag_whitespace(code)
    var subtag_split_index = primary_subtag.find("-")
    if subtag_split_index == -1:
        subtag_split_index = primary_subtag.find("_")
    if subtag_split_index != -1:
        primary_subtag = _trim_language_tag_whitespace(
            String(
                unsafe_from_utf8=Span(
                    unsafe_ptr=primary_subtag.as_bytes().unsafe_ptr(),
                    length=subtag_split_index,
                )
            )
        )
    var folded_primary_subtag = lowercase_ascii_letters_only(primary_subtag)
    if folded_primary_subtag == "pt":
        return ResolvedTaggedLanguage(
            was_recognized=True, language_index=LANG_PT
        )
    if folded_primary_subtag == "en":
        return ResolvedTaggedLanguage(
            was_recognized=True, language_index=LANG_EN
        )
    if folded_primary_subtag == "es":
        return ResolvedTaggedLanguage(
            was_recognized=True, language_index=LANG_ES
        )
    return ResolvedTaggedLanguage(was_recognized=False, language_index=LANG_PT)


def resolve_page_language(requested: String, segment: String) -> Int:

    var resolved_language = parse_tagged_language_prefix(requested)
    if resolved_language.was_recognized:
        return resolved_language.language_index
    return language_code_from_path_segment(segment)


def _fill_filter_node_json(imm filter_node: FilterNode) -> FilterNodeJson:

    return FilterNodeJson(
        id=filter_node.id,
        name=filter_node.name,
        parent_filter_id=optional_when(
            filter_node.has_parent, filter_node.parent
        ),
        name_en=optional_when(filter_node.has_name_en, filter_node.name_en),
        name_es=optional_when(filter_node.has_name_es, filter_node.name_es),
    )


def _render_flat_taxonomy_json_bytes(imm taxonomy: Taxonomy) -> String:

    var nodes = Arr[FilterNodeJson](
        items=map_elements(taxonomy.nodes, _fill_filter_node_json)
    )
    var buffer = SerdeByteBuf(1 << 16)
    serialize_into(nodes, buffer)
    return buffer.to_string()


def _render_flat_taxonomy_localized(
    imm taxonomy: Taxonomy, language: Int
) -> String:
    def localized_json_of_filter_node(
        filter_node: FilterNode,
    ) {language} -> LocalizedFilterJson:
        return LocalizedFilterJson(
            id=filter_node.id,
            name=_pick_localized_name_for_language(filter_node, language),
            parent_filter_id=optional_when(
                filter_node.has_parent, filter_node.parent
            ),
        )

    var nodes = Arr[LocalizedFilterJson](
        items=map_elements(taxonomy.nodes, localized_json_of_filter_node)
    )
    var buffer = SerdeByteBuf(1 << 16)
    serialize_into(nodes, buffer)
    return buffer.to_string()


def _render_grouped_taxonomy_localized(
    imm taxonomy: Taxonomy, language: Int
) raises -> String:
    def root_filter_node_has_english_name(filter_node: FilterNode) -> Bool:
        return (not filter_node.has_parent) and filter_node.has_name_en

    def group_key_of_root_filter_node(filter_node: FilterNode) -> String:
        return lowercase_ascii_letters_only(filter_node.name_en)

    var root_filter_nodes_with_english_name = filter(
        taxonomy.nodes, root_filter_node_has_english_name
    )
    var root_filter_nodes_by_group_key = group_by(
        root_filter_nodes_with_english_name, group_key_of_root_filter_node
    )

    var group_key_by_parent_id = Dict[Int64, String]()

    def remember_group_key_for_root_filter_node(
        mut group_key_by_parent_id: Dict[Int64, String],
        root_filter_node: FilterNode,
    ):
        var group_key = group_key_of_root_filter_node(root_filter_node)
        group_key_by_parent_id[root_filter_node.id] = group_key

    fold_into(
        root_filter_nodes_with_english_name,
        group_key_by_parent_id,
        remember_group_key_for_root_filter_node,
    )

    def group_key_itself(group_key: String) -> String:
        return group_key

    var sorted_group_keys = sort_by(
        List[String](root_filter_nodes_by_group_key.keys()), group_key_itself
    )

    var buffer = SerdeByteBuf(1 << 16)
    buffer.push_ascii(123)
    for selected_key_index in range(len(sorted_group_keys)):
        if selected_key_index > 0:
            buffer.push_ascii(44)
        var selected_group_key = sorted_group_keys[selected_key_index]

        def child_filter_node_belongs_to_selected_group(
            filter_node: FilterNode,
        ) {group_key_by_parent_id, selected_group_key} -> Bool:
            if not filter_node.has_parent:
                return False
            if not (filter_node.parent in group_key_by_parent_id):
                return False
            return (
                group_key_by_parent_id.get(filter_node.parent, String(""))
                == selected_group_key
            )

        var child_filter_nodes = filter(
            taxonomy.nodes, child_filter_node_belongs_to_selected_group
        )
        emit_escaped_json_string(buffer, selected_group_key)
        buffer.push_ascii(58)
        buffer.push_ascii(91)
        var is_first_child = True

        def emit_child_filter_node_into_buffer(
            child_filter_node: FilterNode,
        ) {mut buffer, mut is_first_child, taxonomy, language}:
            if not is_first_child:
                buffer.push_ascii(44)
            is_first_child = False
            var listing_count = taxonomy.counts.get(
                child_filter_node.id, Int64(0)
            )
            if language >= 0:
                var localized_child = GroupedChildLocalizedJson(
                    id=child_filter_node.id,
                    listing_count=listing_count,
                    name=_pick_localized_name_for_language(
                        child_filter_node, language
                    ),
                )
                serialize_into(localized_child, buffer)
            else:
                var legacy_child = GroupedChildJson(
                    id=child_filter_node.id,
                    listing_count=listing_count,
                    name=child_filter_node.name,
                    name_en=optional_when(
                        child_filter_node.has_name_en,
                        child_filter_node.name_en,
                    ),
                    name_es=optional_when(
                        child_filter_node.has_name_es,
                        child_filter_node.name_es,
                    ),
                )
                serialize_into(legacy_child, buffer)

        for_each(child_filter_nodes, emit_child_filter_node_into_buffer)
        buffer.push_ascii(93)
    buffer.push_ascii(125)
    return buffer.to_string()


def build_taxonomy_tree(mut taxonomy: Taxonomy) raises:

    taxonomy.flat_json = _render_flat_taxonomy_json_bytes(taxonomy)
    taxonomy.grouped_json = _render_grouped_taxonomy_localized(taxonomy, -1)
    for language in range(3):
        taxonomy.flat_by_lang[language] = _render_flat_taxonomy_localized(
            taxonomy, language
        )
        taxonomy.grouped_by_lang[language] = _render_grouped_taxonomy_localized(
            taxonomy, language
        )


def _read_prebuilt_body_for_language(
    imm bodies: List[String], language_code: String
) -> Tuple[BytePtr, Int]:

    var body_text = bodies[language_code_from_path_segment(language_code)]
    var body_bytes = body_text.as_bytes()
    return (
        BytePtr(unsafe_from_address=Int(body_bytes.unsafe_ptr())),
        len(body_bytes),
    )


def render_flat_taxonomy_json(
    imm taxonomy: Taxonomy, language_code: String
) -> Tuple[BytePtr, Int]:

    return _read_prebuilt_body_for_language(
        taxonomy.flat_by_lang, language_code
    )


def render_grouped_taxonomy_json(
    imm taxonomy: Taxonomy, language_code: String
) -> Tuple[BytePtr, Int]:

    return _read_prebuilt_body_for_language(
        taxonomy.grouped_by_lang, language_code
    )
