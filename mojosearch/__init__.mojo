"""Mojosearch — the SEARCH domain library: entities, queries, repositories,
services and the two-key nearby cache, served behind the application's
mojoflask layer.

origin: alugue-mojo-api (models/, routes/nearby*, handlers/search/,
services/search/, repositories/, queries/, cache/)

Boundary: this library exposes serve-functions and plain structs. HTTP
transport stays OUT — mojoflask in the application is the web framework;
mojosearch is the domain.

Public API (complete at v0.1.0):
    entities      search-side wire entities incl. the details envelope
                  (wire bytes frozen)
    queries       raw comptime SQL statements + frozen golden contracts
    repositories  SearchRepository / FilterRepository over pqmojo pools
    services      search services, taxonomy render, SearchService
    web           request binding, numeric parsing core, IncomingRequest
                  serve resolvers, state slots and the seed function
    cache         the two-key nearby response cache
    cache_keys    the frozen cache-key derivation (grid + request keys)
"""

from mojosearch.cache import CACHE_CAPACITY, NearbyResponseCache

from mojosearch.cache_keys import (
    KEY_SEPARATOR_PIPE,
    MAX_RESULTS,
    append_cache_key_from_request,
    cache_grid_cell_for_coordinates,
)

from mojosearch.entities import (
    ChildrenIds,
    DetailsJson,
    ERROR_BODY,
    FilterNodeJson,
    GroupedChildJson,
    GroupedChildLocalizedJson,
    ListingCardJson,
    ListingCardRow,
    ListingDetailsRow,
    ListingJson,
    LocalizedFilterJson,
    NearbyListingRow,
    OkResponseWrapperJson,
    PhotoEntries,
    Price,
    QualityJson,
    QualityRow,
    decode_photo_entry,
    details_out_of,
    listing_card_from_row,
    listing_json_from_nearby_row,
    optional_photo_entries_from_optional_list,
    photo_entries_from_list,
)

from mojosearch.queries import (
    DETAILS_SQL,
    POOL_MODULE_DETAILS,
    POOL_MODULE_NEARBY,
    details_and_recommended_prepared_plan,
    nearby_prepared_plan,
    nearby_statement_name,
    recommended_statement_name,
)

from mojosearch.repositories import (
    DETAILS_STATEMENT_NAME,
    FilterNode,
    FilterRepository,
    SearchRepository,
    append_missing_entries_into_union_plan,
    fresh_module_plan_entries,
    make_search_repository,
    union_plan_lacks_statement,
)

from mojosearch.services import (
    NearbyRequest,
    SEARCH_REPOSITORY_ENV,
    SearchService,
    Taxonomy,
    TaxonomyService,
    TaxonomyState,
    TAXONOMY_ENV,
    build_taxonomy_tree,
    install_search_repository,
)

from mojosearch.web import (
    HotReadState,
    MAX_LIMIT,
    NearbyState,
    NearbyStateSlot,
    SearchRowPlan,
    TaxonomyBoot,
    build_details_envelope,
    build_nearby_envelope,
    build_nearby_envelope_exact,
    bind_nearby_request,
    hotread_details_route,
    hotread_rec_route,
    install_taxonomy_serving,
    install_taxonomy_state,
    is_filters_dynamic,
    is_route_dynamic_in_state,
    listing_jsons_from_nearby_rows,
    load_taxonomy_from_state,
    make_hot_read_state,
    make_state,
    market_code_from_request_head,
    parse_filter_ids_from_bytes,
    parse_period_letters_from_bytes,
    parse_postgres_timestamp_nearby_bytes,
    prepare_taxonomy_at_boot,
    resolve_filters,
    seed_canonical_payload_into_state,
    serve_listing_details_route,
    serve_nearby_route,
    serve_published_state_family,
    serve_recommended_listings_route,
)
