"""mojosearch.web.hot_read — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/state_hot_read.mojo + routes/details_and_recommended_routes.mojo
"""

from std.os import getenv

from mojoflask import (
    DynamicOut,
    ResponseBuffer,
    build_response_exact,
    free_bytes,
    make_cstr,
)

from mojoflask.incoming_request import IncomingRequest

from mojoflask.statemod import state_slot_as_type

from mojosearch.entities import ERROR_BODY

from mojosearch.web.handlers import (
    serve_listing_details,
    serve_recommended_listings,
)

from mojosearch.web.state_band import serve_published_state_family

from pqmojo import RowPlan


comptime DEFAULT_SEARCH_DATABASE_URL = "postgres://postgres@localhost/alugue_skinny_clean"


struct SearchRowPlan(Copyable, Movable):

    var plan: RowPlan
    var resolved: Bool

    def __init__(out self):
        self.plan = RowPlan()
        self.resolved = False


@fieldwise_init
struct HotReadState(Movable):

    var details_route: Int
    var recommended_route: Int
    var database_url: String
    var error_buffer: ResponseBuffer
    var not_found_buffer: ResponseBuffer
    var empty_recommended_buffer: ResponseBuffer
    var search_plan: SearchRowPlan


comptime STATE_ENV = "ALUGUE_HOTREAD_STATE"


comptime NOT_FOUND_BODY = '{"error_message":null,"result":[],"has_more":false,"count_total":0,"save_changes_result":0,"type":""}'

comptime EMPTY_RECOMMENDED_BODY = '{"count_total":0,"error_message":null,"has_more":false,"result":[],"save_changes_result":0,"type":""}'


def database_url_at_boot() -> String:

    return getenv("ALUGUE_DB_URL", String(DEFAULT_SEARCH_DATABASE_URL))


def make_state(details_route: Int, recommended_route: Int) -> HotReadState:

    var error_body_cstring = make_cstr(String(ERROR_BODY))
    var error_body_response = build_response_exact(
        "200 OK",
        error_body_cstring,
        String(ERROR_BODY).byte_length(),
        "application/json",
        False,
    )
    free_bytes(error_body_cstring)
    var not_found_body_cstring = make_cstr(String(NOT_FOUND_BODY))
    var not_found_body_response = build_response_exact(
        "200 OK",
        not_found_body_cstring,
        String(NOT_FOUND_BODY).byte_length(),
        "application/json; charset=utf-8",
        True,
    )
    free_bytes(not_found_body_cstring)
    var empty_recommended_body_cstring = make_cstr(
        String(EMPTY_RECOMMENDED_BODY)
    )
    var empty_recommended_body_response = build_response_exact(
        "200 OK",
        empty_recommended_body_cstring,
        String(EMPTY_RECOMMENDED_BODY).byte_length(),
        "application/json; charset=utf-8",
        True,
    )
    free_bytes(empty_recommended_body_cstring)
    return HotReadState(
        details_route=details_route,
        recommended_route=recommended_route,
        database_url=database_url_at_boot(),
        error_buffer=error_body_response,
        not_found_buffer=not_found_body_response,
        empty_recommended_buffer=empty_recommended_body_response,
        search_plan=SearchRowPlan(),
    )


def hotread_details_route(state_address: Int) -> Int:

    var state_slot = state_slot_as_type[HotReadState](state_address)
    return state_slot[].details_route


def hotread_rec_route(state_address: Int) -> Int:

    var state_slot = state_slot_as_type[HotReadState](state_address)
    return state_slot[].recommended_route


def serve_listing_details_route(
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
) -> Bool:

    return serve_published_state_family[HotReadState, serve_listing_details](
        STATE_ENV, request, out_buffer
    )


def serve_recommended_listings_route(
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
) -> Bool:

    return serve_published_state_family[
        HotReadState, serve_recommended_listings
    ](STATE_ENV, request, out_buffer)
