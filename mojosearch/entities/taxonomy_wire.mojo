"""mojosearch.entities.taxonomy_wire — taxonomy render wire DTOs.

origin: alugue-mojo-api services/search/taxonomy_render.mojo
(structs only; the render functions land with mojosearch.services)
"""


@fieldwise_init
struct FilterNodeJson(Copyable, Movable):

    var id: Int64
    var name: String
    var parent_filter_id: Optional[Int64]
    var name_en: Optional[String]
    var name_es: Optional[String]


@fieldwise_init
struct LocalizedFilterJson(Copyable, Movable):

    var id: Int64
    var name: String
    var parent_filter_id: Optional[Int64]


@fieldwise_init
struct GroupedChildJson(Copyable, Movable):

    var id: Int64
    var listing_count: Int64
    var name: String
    var name_en: Optional[String]
    var name_es: Optional[String]


@fieldwise_init
struct GroupedChildLocalizedJson(Copyable, Movable):

    var id: Int64
    var listing_count: Int64
    var name: String
