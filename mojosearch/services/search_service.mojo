"""Mojosearch services search_service — the read-side search service over
the published SearchRepository and the two-key nearby cache, moved
verbatim from the application, wire bytes frozen.

The application resolves its repository singleton through a state slot
published at boot; this library ports that resolution with
install_search_repository + the SEARCH_REPOSITORY_ENV slot so the serve
signatures stay identical to the application's.

origin: alugue-mojo-api services/search/search_service.mojo
(+ repositories/repository.mojo state-slot resolution)
"""

from mojoflask import (
    METHOD_QUERY,
    STATUS_OK,
    Brotli as BrotliEncoder,
    BytePtr,
    DynamicOut,
    ResponseBuffer,
    UntrackedBytePtr,
    build_response_exact,
    free_bytes,
    retracked,
    send_response,
)

from mojoflask.statemod import (
    find_published_state_address,
    publish_state_address,
    state_slot_as_type,
)

from mojoka import StoredBytes

from mojosearch.cache import NearbyResponseCache

from mojosearch.entities.listing import NearbyListingRow

from mojosearch.entities.listing_details import ListingDetailsRow

from mojosearch.repositories.search_repository import SearchRepository

from mojosearch.web.nearby_writer import (
    build_nearby_envelope,
    listing_jsons_from_nearby_rows,
)

from mojosearch.cache_keys import (
    MAX_RESULTS,
    append_cache_key_from_request,
    cache_grid_cell_for_coordinates,
)

from mojosearch.services.nearby_request import NearbyRequest


comptime SEARCH_REPOSITORY_ENV = "ALUGUE_SEARCH_REPOSITORY_STATE"


def body_start_of_stored_response(data: BytePtr, total: Int) -> Int:

    var byte_index = 0
    var scan_limit = total - 3
    while byte_index < scan_limit:
        if (
            Int(data[unsafe_offset=byte_index]) == 13
            and Int(data[unsafe_offset=byte_index + 1]) == 10
            and Int(data[unsafe_offset=byte_index + 2]) == 13
            and Int(data[unsafe_offset=byte_index + 3]) == 10
        ):
            return byte_index + 4
        byte_index += 1
    return total


def _store_brotli_variant(
    mut cache: NearbyResponseCache,
    serving_hash: UInt64,
    method_code: UInt8,
    identity_data: UntrackedBytePtr,
    identity_length: Int,
) raises -> Optional[StoredBytes]:

    var body_start = body_start_of_stored_response(
        retracked(identity_data), identity_length
    )
    var body_length = identity_length - body_start
    if body_length <= 0:
        return Optional[StoredBytes]()
    var encoder = BrotliEncoder()
    var packed_bytes = encoder.compress(
        BytePtr(unsafe_from_address=Int(identity_data) + body_start),
        body_length,
    )
    if packed_bytes[1] <= 0:
        return Optional[StoredBytes]()
    var allow_header = (
        "Allow: GET,HEAD\r\n" if method_code == METHOD_QUERY else ""
    )
    var br_response_bytes = build_response_exact(
        STATUS_OK,
        packed_bytes[0],
        packed_bytes[1],
        "application/json; charset=utf-8",
        True,
        "Content-Encoding: br\r\n" + allow_header,
    )
    free_bytes(packed_bytes[0])
    return Optional[StoredBytes](
        cache.set_br(
            serving_hash,
            retracked(br_response_bytes.data),
            br_response_bytes.length,
        )
    )


def install_search_repository(
    repository_to_install: SearchRepository,
) -> Bool:
    return publish_state_address[SearchRepository](
        Int(Pointer(to=repository_to_install)), SEARCH_REPOSITORY_ENV
    )


struct SearchService:
    @staticmethod
    def details_row(listing_id: Int64) raises -> List[ListingDetailsRow]:

        var repository_slot = state_slot_as_type[SearchRepository](
            find_published_state_address(SEARCH_REPOSITORY_ENV)
        )
        return repository_slot[].details_rows[ListingDetailsRow](listing_id)

    @staticmethod
    def recommended_rows(
        latitude: Float64,
        longitude: Float64,
        coordinates_present: Bool,
        window: Int,
        filter_ids: List[Int32],
        periods: List[UInt8],
    ) raises -> List[NearbyListingRow]:

        var repository_slot = state_slot_as_type[SearchRepository](
            find_published_state_address(SEARCH_REPOSITORY_ENV)
        )
        return repository_slot[].recommended_rows[NearbyListingRow](
            latitude,
            longitude,
            coordinates_present,
            window,
            filter_ids,
            periods,
        )

    @staticmethod
    def nearby_rows(
        latitude: Float64,
        longitude: Float64,
        coordinates_present: Bool,
        window: Int,
        filter_ids: List[Int32],
        periods: List[UInt8],
    ) raises -> List[NearbyListingRow]:

        var repository_slot = state_slot_as_type[SearchRepository](
            find_published_state_address(SEARCH_REPOSITORY_ENV)
        )
        return repository_slot[].nearby_rows[NearbyListingRow](
            latitude,
            longitude,
            coordinates_present,
            window,
            filter_ids,
            periods,
        )

    @staticmethod
    def nearby(
        mut cache: NearbyResponseCache,
        error_response: ResponseBuffer,
        method_code: UInt8,
        market: StaticString,
        request: NearbyRequest,
        accepts_brotli: Bool,
        mut out_buffer: DynamicOut,
    ):

        var grid = cache_grid_cell_for_coordinates(
            request.lat, request.lng, request.has_geo
        )
        append_cache_key_from_request(
            cache.key_builder, market, request, grid[0], grid[1]
        )
        var base_hash = cache.mark_identity_key(method_code == METHOD_QUERY)
        var serving_hash = base_hash
        if accepts_brotli:
            serving_hash = cache.extend_br_key()

        var cached_hit = cache.get_br(
            serving_hash
        ) if accepts_brotli else cache.get_identity(base_hash)
        if cached_hit.len > 0:
            out_buffer.data = cached_hit.data
            out_buffer.length = cached_hit.len
            out_buffer.owns = False
            out_buffer.static_route = -1
            return

        if accepts_brotli:
            try:
                var base_hit = cache.get_identity(base_hash)
                if base_hit.len > 0:
                    var br_served = _store_brotli_variant(
                        cache,
                        serving_hash,
                        method_code,
                        base_hit.data,
                        base_hit.len,
                    )
                    if br_served:
                        out_buffer.data = br_served.value().data
                        out_buffer.length = br_served.value().len
                        out_buffer.owns = False
                        out_buffer.static_route = -1
                        return
            except:
                pass

        var window = request.skip + request.limit + 1
        if window > MAX_RESULTS + 1:
            window = MAX_RESULTS + 1

        var repository_slot = state_slot_as_type[SearchRepository](
            find_published_state_address(SEARCH_REPOSITORY_ENV)
        )
        var rows = List[NearbyListingRow]()
        try:
            rows = repository_slot[].nearby_rows[NearbyListingRow](
                request.lat,
                request.lng,
                request.has_geo,
                window,
                request.filters,
                request.periods,
            )
        except:
            send_response(error_response, out_buffer)
            return

        var listings = listing_jsons_from_nearby_rows(rows, request.has_geo)
        var serialized_wrapper = build_nearby_envelope(
            listings^, request.skip, request.limit, request.has_geo, MAX_RESULTS
        )
        var allow_header = (
            "Allow: GET,HEAD\r\n" if method_code == METHOD_QUERY else ""
        )
        var response_bytes = build_response_exact(
            STATUS_OK,
            serialized_wrapper[0],
            serialized_wrapper[1],
            "application/json; charset=utf-8",
            True,
            allow_header,
        )
        free_bytes(serialized_wrapper[0])

        var identity_served = cache.set_identity(
            base_hash, retracked(response_bytes.data), response_bytes.length
        )
        var served_bytes = identity_served.data
        var served_length = identity_served.len
        if accepts_brotli:
            try:
                var br_served = _store_brotli_variant(
                    cache,
                    serving_hash,
                    method_code,
                    served_bytes,
                    served_length,
                )
                if br_served:
                    served_bytes = br_served.value().data
                    served_length = br_served.value().len
            except:
                pass
        out_buffer.data = served_bytes
        out_buffer.length = served_length
        out_buffer.owns = False
        out_buffer.static_route = -1
