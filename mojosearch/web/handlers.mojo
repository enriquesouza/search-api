"""mojosearch.web.handlers — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api handlers/search/**
"""

from mojoflask import (
    BytePtr,
    DynamicOut,
    ResponseBuffer,
    build_response_exact,
    free_bytes,
    malloc_bytes,
    retracked,
)

from mojoflask.incoming_request import IncomingRequest

from mojoflask.reqscan import (
    raw_query_text_from_request_line,
    url_path_segment_as_range,
    url_path_segment_as_string,
)

from mojoflask.serving import (
    RESPONSE_HEADER_TAIL,
    send_response,
    send_response_taking_ownership_of_bytes,
)

from mojoflask.statemod import StateSlot

from mojoflask.text import range_equals_literal

from mojoserde import parse_whole_number_from_bytes

from mojoserde.buf import pow10_u64, uint_digits

from mojosearch.entities import (
    DetailsJson,
    ListingDetailsRow,
    details_out_of,
)

from mojosearch.cache_keys import MAX_RESULTS

from mojosearch.services.search_service import SearchService

from mojosearch.services.taxonomy_render import resolve_page_language

from mojosearch.services.taxonomy_service import FiltersQuery, TaxonomyService

from mojosearch.services.taxonomy_state import TaxonomyState

from mojosearch.web.binding import (
    NearbyRequest,
    _bind_query_string,
    bind_nearby_request,
)

from mojosearch.web.hot_read import HotReadState

from mojosearch.web.market_code import market_code_from_request_head

from mojosearch.web.nearby_writer import (
    build_nearby_envelope_exact,
    listing_jsons_from_nearby_rows,
)

from mojosearch.web.state_and_seed import NearbyStateSlot


def _send_ok_response_wrapper_bytes(
    serialized_wrapper: Tuple[BytePtr, Int], mut out_buffer: DynamicOut
):

    var response = build_response_exact(
        "200 OK",
        serialized_wrapper[0],
        serialized_wrapper[1],
        "application/json; charset=utf-8",
        True,
    )
    free_bytes(serialized_wrapper[0])
    send_response_taking_ownership_of_bytes(
        retracked(response.data), response.length, out_buffer
    )


comptime ACCEPT_ENCODING_LOWER = ("accept-encoding:".as_bytes())


def request_accepts_brotli(request_head: BytePtr, head_length: Int) -> Bool:

    var header_scan_index = 0
    var header_scan_limit = head_length - 16
    while header_scan_index < header_scan_limit:
        var literal_matched = True
        var literal_index = 0
        while literal_index < 16:
            var header_byte = Int(
                request_head[unsafe_offset=header_scan_index + literal_index]
            )
            if header_byte >= 65 and header_byte <= 90:
                header_byte += 32
            var literal_byte = Int(ACCEPT_ENCODING_LOWER[literal_index])
            if header_byte != literal_byte:
                literal_matched = False
                break
            literal_index += 1
        if literal_matched:
            var value_index = header_scan_index + 16
            while value_index < head_length:
                var value_byte = Int(request_head[unsafe_offset=value_index])
                if value_byte == 13:
                    break
                if value_byte == 98 and value_index + 2 < head_length:
                    var next_byte = Int(
                        request_head[unsafe_offset=value_index + 1]
                    )
                    var after_byte = Int(
                        request_head[unsafe_offset=value_index + 2]
                    )
                    if next_byte == 114 and (
                        after_byte == 44
                        or after_byte == 13
                        or after_byte == 10
                        or after_byte == 59
                        or after_byte == 32
                        or after_byte == 61
                    ):
                        return True
                value_index += 1
            return False
        header_scan_index += 1
    return False


def serve_nearby(
    nearby_state: NearbyStateSlot,
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
):

    # Step 1 — Bind the nearby request from the method, head and body.
    var bound_nearby_request = bind_nearby_request(
        request.method_code,
        retracked(request.head),
        request.head_length,
        retracked(request.body),
        request.body_length,
    )
    # Step 2 — Read the market and the Brotli preference from the head.
    var market = market_code_from_request_head(
        retracked(request.head), request.head_length
    )
    var accepts_brotli = request_accepts_brotli(
        retracked(request.head), request.head_length
    )
    # Step 3 — Run the nearby search, which sends the response.
    SearchService.nearby(
        nearby_state[].cache,
        nearby_state[].error_buffer,
        request.method_code,
        market,
        bound_nearby_request^,
        accepts_brotli,
        out_buffer,
    )


comptime BAD_ID_STATUS_LINE = "HTTP/1.1 400 Bad Request"
comptime BAD_ID_TEXT_FIELDS = (
    "\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: "
)

comptime BAD_ID_MESSAGE_BEFORE_ID = (
    "Invalid URL: Cannot parse value at index 1 with value `"
)
comptime BAD_ID_MESSAGE_AFTER_ID = "` to a `i64`"

comptime ASCII_DIGIT_ZERO = 48

comptime DETAILS_ID_SEGMENT = 3


def _splice_text_into_buffer(
    buffer_address: Int, start_index: Int, text: String
) -> Int:

    var destination = BytePtr(unsafe_from_address=buffer_address)
    var write_index = start_index
    for byte in text.bytes():
        destination[write_index] = byte
        write_index += 1
    return write_index


def _splice_decimal_into_buffer(
    buffer_address: Int, start_index: Int, value: UInt64
) -> Int:

    var destination = BytePtr(unsafe_from_address=buffer_address)
    var digit_count = uint_digits(value)
    var place_value = pow10_u64(digit_count - 1)
    var write_index = start_index
    var digit_index = 0
    while digit_index < digit_count:
        destination[write_index] = Byte(
            ASCII_DIGIT_ZERO + Int((value // place_value) % 10)
        )
        place_value //= 10
        write_index += 1
        digit_index += 1
    return write_index


def _splice_bytes_into_buffer(
    buffer_address: Int, start_index: Int, source: BytePtr, byte_count: Int
) -> Int:

    var destination = BytePtr(unsafe_from_address=buffer_address)
    var write_index = start_index
    var source_index = 0
    while source_index < byte_count:
        destination[write_index] = source[source_index]
        write_index += 1
        source_index += 1
    return write_index


def _reject_bad_id_segment(
    id_pointer: BytePtr, id_length: Int, mut out_buffer: DynamicOut
):

    var header_prefix = BAD_ID_STATUS_LINE + BAD_ID_TEXT_FIELDS
    var message_length = (
        String(BAD_ID_MESSAGE_BEFORE_ID).byte_length()
        + id_length
        + String(BAD_ID_MESSAGE_AFTER_ID).byte_length()
    )
    var response_length = (
        header_prefix.byte_length()
        + uint_digits(UInt64(message_length))
        + String(RESPONSE_HEADER_TAIL).byte_length()
        + message_length
    )
    var response_bytes = malloc_bytes(response_length)
    var buffer_address = Int(response_bytes)
    var write_index = _splice_text_into_buffer(buffer_address, 0, header_prefix)
    write_index = _splice_decimal_into_buffer(
        buffer_address, write_index, UInt64(message_length)
    )
    write_index = _splice_text_into_buffer(
        buffer_address, write_index, String(RESPONSE_HEADER_TAIL)
    )

    write_index = _splice_text_into_buffer(
        buffer_address, write_index, String(BAD_ID_MESSAGE_BEFORE_ID)
    )
    write_index = _splice_bytes_into_buffer(
        buffer_address, write_index, id_pointer, id_length
    )
    _ = _splice_text_into_buffer(
        buffer_address, write_index, String(BAD_ID_MESSAGE_AFTER_ID)
    )
    send_response_taking_ownership_of_bytes(
        response_bytes, response_length, out_buffer
    )


def serve_listing_details(
    hot_read_state: StateSlot[HotReadState],
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
):

    # Step 1 — Read the listing id segment from the URL path.
    var id_segment_byte_range = url_path_segment_as_range(
        retracked(request.head), request.head_length, DETAILS_ID_SEGMENT
    )
    if id_segment_byte_range[1] <= id_segment_byte_range[0]:
        return
    var id_pointer = retracked(request.head) + id_segment_byte_range[0]
    var id_length = id_segment_byte_range[1] - id_segment_byte_range[0]
    # Step 2 — Reject ids that are not whole numbers.
    var parsed_id = parse_whole_number_from_bytes(id_pointer, id_length)
    if not parsed_id[1]:
        _reject_bad_id_segment(id_pointer, id_length, out_buffer)
        return

    # Step 3 — Load the details row and send the wrapped envelope, or send the not-found or error response.
    var details_rows = List[ListingDetailsRow]()
    try:
        details_rows = SearchService.details_row(parsed_id[0])
    except:
        send_response(hot_read_state[].error_buffer, out_buffer)
        return
    if len(details_rows) == 0:
        send_response(hot_read_state[].not_found_buffer, out_buffer)
        return

    _send_ok_response_wrapper_bytes(
        build_details_envelope(details_out_of(details_rows[0])), out_buffer
    )


def serve_recommended_listings(
    hot_read_state: StateSlot[HotReadState],
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
):

    # Step 1 — Bind the query string into the nearby request shape.
    var nearby_query = NearbyRequest()
    _bind_query_string(
        retracked(request.head), request.head_length, nearby_query
    )
    # Step 2 — Send the empty recommended buffer when no filters were given.
    if len(nearby_query.filters) == 0:
        send_response(hot_read_state[].empty_recommended_buffer, out_buffer)
        return

    # Step 3 — Clamp the fetch window to the maximum results.
    var fetch_window = nearby_query.limit + 1
    if fetch_window > MAX_RESULTS + 1:
        fetch_window = MAX_RESULTS + 1

    try:
        # Step 4 — Load the recommended rows and send the wrapped envelope, or send the error response.
        var recommended_rows = SearchService.recommended_rows(
            nearby_query.lat,
            nearby_query.lng,
            nearby_query.has_geo,
            fetch_window,
            nearby_query.filters,
            nearby_query.periods,
        )
        var listings = listing_jsons_from_nearby_rows(
            recommended_rows, nearby_query.has_geo
        )

        _send_ok_response_wrapper_bytes(
            build_nearby_envelope_exact(
                listings^,
                0,
                nearby_query.limit,
                nearby_query.has_geo,
                MAX_RESULTS,
                False,
            ),
            out_buffer,
        )
    except:
        send_response(hot_read_state[].error_buffer, out_buffer)


def bind_filters_query(request_head: BytePtr, head_length: Int) -> FiltersQuery:

    var filter_query = FiltersQuery(
        flat_request_mode=0, has_language_tag=False, resolved_language=0
    )
    var query_byte_range = raw_query_text_from_request_line(
        request_head, head_length
    )
    var query_start = query_byte_range[0]
    var query_end = query_byte_range[1]

    var flat_value_pointer = request_head
    var flat_value_length = -1
    var flat_pair_count = 0
    var language_value_pointer = request_head
    var language_value_length = -1

    var scan_position = query_start
    while scan_position < query_end:
        var ampersand_position = scan_position
        while (
            ampersand_position < query_end
            and Int(request_head[ampersand_position]) != 38
        ):
            ampersand_position += 1
        var equals_position = scan_position
        while (
            equals_position < ampersand_position
            and Int(request_head[equals_position]) != 61
        ):
            equals_position += 1
        var key_length = equals_position - scan_position
        var value_start = equals_position + 1
        var value_length = ampersand_position - value_start
        if equals_position == ampersand_position:
            value_start = ampersand_position
            value_length = 0
        if key_length == 4 and range_equals_literal(
            request_head + scan_position, "flat"
        ):
            flat_pair_count += 1
            if flat_value_length < 0:
                flat_value_pointer = request_head + value_start
                flat_value_length = value_length
        elif key_length == 4 and range_equals_literal(
            request_head + scan_position, "lang"
        ):
            if language_value_length < 0:
                language_value_pointer = request_head + value_start
                language_value_length = value_length
        scan_position = ampersand_position + 1

    if flat_value_length >= 0:
        if flat_value_length == 4 and range_equals_literal(
            flat_value_pointer, "true"
        ):
            filter_query.flat_request_mode = 1
        elif flat_value_length == 5 and range_equals_literal(
            flat_value_pointer, "false"
        ):
            filter_query.flat_request_mode = 2
        else:
            filter_query.flat_request_mode = 3
    if flat_pair_count > 1 and filter_query.flat_request_mode != 3:
        filter_query.flat_request_mode = 4
    if language_value_length >= 0:
        filter_query.has_language_tag = True
        var segment = url_path_segment_as_string(request_head, head_length)
        var requested = String(
            unsafe_from_utf8=Span(
                unsafe_ptr=language_value_pointer,
                length=language_value_length,
            )
        )
        filter_query.resolved_language = resolve_page_language(
            requested, segment
        )
    return filter_query^


def serve_taxonomy_filters(
    taxonomy_state: StateSlot[TaxonomyState],
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
):

    # Step 1 — Select the filters response for the bound query, or the error buffer when the taxonomy state is not live.
    var selected_response: ResponseBuffer
    if not taxonomy_state[].live:
        selected_response = taxonomy_state[].response_erroror
    else:
        var filter_query = bind_filters_query(
            retracked(request.head), request.head_length
        )
        selected_response = TaxonomyService.filters_response_for_query(
            taxonomy_state[], filter_query
        )

    # Step 2 — Copy the selected response into the output buffer.
    out_buffer.data = selected_response.data
    out_buffer.length = selected_response.length
    out_buffer.owns = False
    out_buffer.static_route = -1


def serve_taxonomy_filters_id(
    route_index: Int,
    taxonomy_state: StateSlot[TaxonomyState],
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
):

    # Step 1 — Ignore requests that are not the dynamic filters route.
    if route_index != taxonomy_state[].filters_dyn_route:
        return
    # Step 2 — Serve the filters response for this request.
    serve_taxonomy_filters(taxonomy_state, request, out_buffer)
