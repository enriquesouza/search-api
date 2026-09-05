from mojoflask import ResponseBuffer

from std.collections import Dict

from mojosearch.repositories.filter_repository import FilterNode


comptime TAXONOMY_ENV = "ALUGUE_TAXONOMY_STATE"


comptime LANG_PT = 0
comptime LANG_ES = 1
comptime LANG_EN = 2


@fieldwise_init
struct Taxonomy(Movable):

    var nodes: List[FilterNode]
    var counts: Dict[Int64, Int64]
    var flat_json: String
    var grouped_json: String
    var flat_by_lang: List[String]
    var grouped_by_lang: List[String]

    def __init__(out self):
        self.nodes = List[FilterNode]()
        self.counts = Dict[Int64, Int64]()
        self.flat_json = String("")
        self.grouped_json = String("")
        self.flat_by_lang = List[String](capacity=3)
        self.flat_by_lang.append(String(""))
        self.flat_by_lang.append(String(""))
        self.flat_by_lang.append(String(""))
        self.grouped_by_lang = List[String](capacity=3)
        self.grouped_by_lang.append(String(""))
        self.grouped_by_lang.append(String(""))
        self.grouped_by_lang.append(String(""))


@fieldwise_init
struct TaxonomyState(Movable):

    var live: Bool
    var filters_dyn_route: Int
    var response_flat: ResponseBuffer
    var response_grouped: ResponseBuffer
    var response_flat_pt: ResponseBuffer
    var response_flat_es: ResponseBuffer
    var response_flat_en: ResponseBuffer
    var response_grouped_pt: ResponseBuffer
    var response_grouped_es: ResponseBuffer
    var response_grouped_en: ResponseBuffer
    var response_bad_query_string: ResponseBuffer
    var response_duplicate_field: ResponseBuffer
    var response_erroror: ResponseBuffer

    def flat_response_for_language(imm self, language: Int) -> ResponseBuffer:

        if language == LANG_PT:
            return self.response_flat_pt
        if language == LANG_ES:
            return self.response_flat_es
        return self.response_flat_en

    def grouped_response_for_language(
        imm self, language: Int
    ) -> ResponseBuffer:

        if language == LANG_PT:
            return self.response_grouped_pt
        if language == LANG_ES:
            return self.response_grouped_es
        return self.response_grouped_en
