"""mojosearch.web.state_and_seed — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby/_state_and_seed.mojo
"""

from std.os import getenv

from mojoflask import (
    build_response_exact,
    ResponseBuffer,
    free_bytes,
    make_cstr,
    malloc_bytes,
    read_file_into,
)

from mojoka import (
    KeyBuilder,
    SlotTable,
    retracked,
)

from mojosearch.cache import CACHE_CAPACITY, NearbyResponseCache

from mojosearch.entities import ERROR_BODY
from mojosearch.web.hot_read import SearchRowPlan

from mojosearch.cache_keys import (
    append_cache_key_from_request,
    cache_grid_cell_for_coordinates,
)
from mojosearch.web.numeric_core import ASCII_DIGIT_HI, ASCII_DIGIT_LO
from mojosearch.web.binding import MAX_LIMIT, NearbyRequest


comptime DEFAULT_TTL_SECONDS = 60
comptime TTL_MAX_SECONDS = 86400


comptime SEED_CANONICAL_LATITUDE = -23.5505
comptime SEED_CANONICAL_LONGITUDE = -46.6333
comptime SEED_PAYLOAD_CAPACITY = 1 << 19


comptime STATE_ENV = "ALUGUE_NEARBY_STATE"


comptime NearbyStateSlot = Pointer[T=NearbyState, mut=True, origin=MutAnyOrigin]


@fieldwise_init
struct NearbyState(Movable):

    var cache: NearbyResponseCache
    var error_buffer: ResponseBuffer
    var search_plan: SearchRowPlan


def env_seconds_or_default(environment_key: String, default_value: Int) -> Int:

    var raw_value = getenv(environment_key, "")
    var seconds_value = 0
    for character_value in raw_value:
        var digit_value = ord(character_value)
        if digit_value < ASCII_DIGIT_LO or digit_value > ASCII_DIGIT_HI:
            return default_value
        seconds_value = seconds_value * 10 + (digit_value - ASCII_DIGIT_LO)
    if seconds_value == 0:
        return default_value if raw_value == "" else 1
    if seconds_value > TTL_MAX_SECONDS:
        return TTL_MAX_SECONDS
    return seconds_value


def make_state() -> NearbyState:

    var ttl_seconds = env_seconds_or_default(
        "ALUGUE_SEARCH_CACHE_TTL", DEFAULT_TTL_SECONDS
    )
    var mmap_values = getenv("MOJOFLASK_MMAP_VALUES", "1") != "0"
    var error_c_string = make_cstr(String(ERROR_BODY))
    var error_response = build_response_exact(
        "200 OK",
        error_c_string,
        String(ERROR_BODY).byte_length(),
        "application/json",
        False,
    )
    free_bytes(error_c_string)
    return NearbyState(
        cache=NearbyResponseCache(
            slots=SlotTable(CACHE_CAPACITY, ttl_seconds * 1_000_000_000),
            key_builder=KeyBuilder(),
            identity_length=0,
            mmap_values=mmap_values,
        ),
        error_buffer=error_response,
        search_plan=SearchRowPlan(),
    )


def seed_canonical_payload_into_state(
    mut state: NearbyState, payload_path: String
) -> Bool:

    var source = malloc_bytes(SEED_PAYLOAD_CAPACITY)
    var read_length = read_file_into(
        payload_path, source, SEED_PAYLOAD_CAPACITY
    )
    if read_length <= 0:
        free_bytes(source)
        return False
    var payload_response = build_response_exact(
        "200 OK", source, read_length, "application/json; charset=utf-8", True
    )
    free_bytes(source)

    var request = NearbyRequest()
    request.limit = MAX_LIMIT
    request.lat = SEED_CANONICAL_LATITUDE
    request.lng = SEED_CANONICAL_LONGITUDE
    request.has_geo = True

    var grid = cache_grid_cell_for_coordinates(
        request.lat, request.lng, request.has_geo
    )
    append_cache_key_from_request(
        state.cache.key_builder, "br", request, grid[0], grid[1]
    )
    var base_hash = state.cache.mark_identity_key(False)
    _ = state.cache.set_identity(
        base_hash, retracked(payload_response.data), payload_response.length
    )
    return True
