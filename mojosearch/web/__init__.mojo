"""mojosearch.web — nearby/details/recommended/filters serving surface.

origin: alugue-mojo-api routes/nearby/**, routes/nearby_response_writer.mojo,
routes/details_and_recommended_routes.mojo, routes/state_hot_read.mojo,
routes/_state_band.mojo, routes/taxonomy_routes.mojo, handlers/search/**

Boundary: this package exposes state make/install/is_dynamic functions, the
serve_* resolvers (IncomingRequest carriers + DynamicOut) and the seed
function. HTTP transport stays OUT — the application's mojoflask layer owns
route registration and calls these resolvers.
"""

from mojosearch.web.binding import (
    MAX_LIMIT,
    NearbyRequest,
    bind_nearby_request,
)
from mojosearch.web.hot_read import (
    STATE_ENV as HOTREAD_STATE_ENV,
    HotReadState,
    SearchRowPlan,
    hotread_details_route,
    hotread_rec_route,
    make_state as make_hot_read_state,
    serve_listing_details_route,
    serve_recommended_listings_route,
)
from mojosearch.web.market_code import market_code_from_request_head
from mojosearch.web.nearby_writer import (
    build_details_envelope,
    build_nearby_envelope,
    build_nearby_envelope_exact,
    listing_jsons_from_nearby_rows,
)
from mojosearch.web.numeric_core import (
    parse_filter_ids_from_bytes,
    parse_period_letters_from_bytes,
    parse_postgres_timestamp_nearby_bytes,
)
from mojosearch.web.serve_nearby_route import serve_nearby_route
from mojosearch.web.state_and_seed import (
    STATE_ENV as NEARBY_STATE_ENV,
    NearbyState,
    NearbyStateSlot,
    make_state,
    seed_canonical_payload_into_state,
)
from mojosearch.web.state_band import (
    is_route_dynamic_in_state,
    serve_published_state_family,
)
from mojosearch.web.taxonomy import (
    TaxonomyBoot,
    install_taxonomy_serving,
    install_taxonomy_state,
    is_filters_dynamic,
    load_taxonomy_from_state,
    prepare_taxonomy_at_boot,
    resolve_filters,
)
