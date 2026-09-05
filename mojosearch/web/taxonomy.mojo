"""mojosearch.web.taxonomy — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/taxonomy_routes.mojo
"""

from mojoflask import (
    DynamicOut,
    ResponseBuffer,
    build_response_exact,
)

from mojosearch.entities import ERROR_BODY
from mojoflask.incoming_request import IncomingRequest

from pqmojo import PgConn

from mojosearch.web.handlers import (
    serve_taxonomy_filters,
    serve_taxonomy_filters_id,
)

from mojosearch.queries.search_queries import open_connection_after_fork

from mojosearch.services.taxonomy_render import build_taxonomy_tree

from mojosearch.services.taxonomy_service import TaxonomyService

from mojosearch.services.taxonomy_state import (
    TAXONOMY_ENV,
    Taxonomy,
    TaxonomyState,
)

from mojoflask.serving import build_preformatted_text_response

from mojoflask.reqscan import request_body_range

from mojosearch.web.state_band import (
    is_route_dynamic_in_state,
    serve_published_state_family,
)

from mojoflask.statemod import (
    StateSlot,
    publish_state_slot,
)


comptime BAD_QUERY_STRING_BODY = "Failed to deserialize query string: flat: provided string was not `true` or `false`"

comptime DUP_FLAT_FIELD_BODY = "Failed to deserialize query string: duplicate field `flat`"


@fieldwise_init
struct TaxonomyBoot(Movable):

    var taxonomy: Taxonomy
    var is_live: Bool


def load_taxonomy_from_state(connection: PgConn) raises -> Taxonomy:

    var taxonomy = Taxonomy()
    taxonomy.nodes = TaxonomyService.visible_nodes(connection)
    taxonomy.counts = TaxonomyService.counts(connection)
    build_taxonomy_tree(taxonomy)
    return taxonomy^


def prepare_taxonomy_at_boot(database_url: String) -> TaxonomyBoot:

    try:
        var connection = open_connection_after_fork(database_url)
        var taxonomy: Taxonomy
        try:
            taxonomy = load_taxonomy_from_state(connection)
        except:
            connection.close()
            return TaxonomyBoot(taxonomy=Taxonomy(), is_live=False)
        connection.close()
        return TaxonomyBoot(taxonomy=taxonomy^, is_live=True)
    except:
        return TaxonomyBoot(taxonomy=Taxonomy(), is_live=False)


def build_preformatted_response(
    status: String, body: String, server_name: String
) -> ResponseBuffer:
    _ = server_name
    var body_range = request_body_range(body)
    return build_response_exact(
        status,
        body_range[0],
        body_range[1],
        "application/json; charset=utf-8",
        True,
    )


def install_taxonomy_serving(
    imm taxonomy: Taxonomy,
    live: Bool,
    dynamic_filters_route_index: Int,
    server_name: String,
) -> Bool:

    var state = TaxonomyState(
        live=live,
        filters_dyn_route=dynamic_filters_route_index,
        response_flat=build_preformatted_response(
            "200 OK", taxonomy.flat_json, server_name
        ),
        response_grouped=build_preformatted_response(
            "200 OK", taxonomy.grouped_json, server_name
        ),
        response_flat_pt=build_preformatted_response(
            "200 OK", taxonomy.flat_by_lang[0], server_name
        ),
        response_flat_es=build_preformatted_response(
            "200 OK", taxonomy.flat_by_lang[1], server_name
        ),
        response_flat_en=build_preformatted_response(
            "200 OK", taxonomy.flat_by_lang[2], server_name
        ),
        response_grouped_pt=build_preformatted_response(
            "200 OK", taxonomy.grouped_by_lang[0], server_name
        ),
        response_grouped_es=build_preformatted_response(
            "200 OK", taxonomy.grouped_by_lang[1], server_name
        ),
        response_grouped_en=build_preformatted_response(
            "200 OK", taxonomy.grouped_by_lang[2], server_name
        ),
        response_bad_query_string=build_preformatted_text_response(
            "400 Bad Request",
            "text/plain; charset=utf-8",
            String(BAD_QUERY_STRING_BODY),
        ),
        response_duplicate_field=build_preformatted_text_response(
            "400 Bad Request",
            "text/plain; charset=utf-8",
            String(DUP_FLAT_FIELD_BODY),
        ),
        response_erroror=build_preformatted_response(
            "200 OK", String(ERROR_BODY), server_name
        ),
    )
    return install_taxonomy_state(state)


def install_taxonomy_state(mut state: TaxonomyState) -> Bool:

    return publish_state_slot[TaxonomyState](state, TAXONOMY_ENV)


def taxonomy_state_routes(
    state_slot: StateSlot[TaxonomyState], route_index: Int
) -> Bool:
    return route_index == state_slot[].filters_dyn_route


def is_filters_dynamic(route_index: Int) -> Bool:

    return is_route_dynamic_in_state[TaxonomyState, taxonomy_state_routes](
        TAXONOMY_ENV, route_index
    )


def resolve_filters(
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
) -> Bool:

    return serve_published_state_family[TaxonomyState, serve_taxonomy_filters](
        TAXONOMY_ENV, request, out_buffer
    )
