"""mojosearch.web.binding — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby/_request_binding.mojo
"""

from mojoflask import (
    METHOD_QUERY,
    BytePtr,
    parse_json_body,
)

from emberjson import Value, try_parse

from mojoflask.reqscan import raw_query_text_from_request_line
from mojoflask.text import range_equals_literal

from mojosearch.web.numeric_core import (
    CH_MINUS,
    CH_PIPE,
    _append_decimal_digit_characters,
    _clamp_degrees_to_limit,
    _parse_clamped_degrees_from_bytes,
    _parse_whole_number_strict,
    parse_filter_ids_from_bytes,
    parse_period_letters_from_bytes,
)

from mojosearch.services.nearby_request import NearbyRequest


comptime MAX_LIMIT = 300


comptime LAT_LIMIT_DEGREES = 90.0


comptime LNG_LIMIT_DEGREES = 180.0


comptime RANGE_ABSENT = -1


@fieldwise_init
struct _RequestParamRange(Copyable, Movable):

    var offset: Int
    var length: Int

    def absent(self) -> Bool:
        return self.offset == RANGE_ABSENT


def _absent_range() -> _RequestParamRange:

    return _RequestParamRange(RANGE_ABSENT, 0)


def _query_key_is(
    request_head: BytePtr,
    key_position: Int,
    key_length: Int,
    key_name: StaticString,
) -> Bool:

    return key_length == key_name.byte_length() and range_equals_literal(
        request_head + key_position, key_name
    )


def _bind_query_string(
    request_head: BytePtr, head_length: Int, mut request: NearbyRequest
):

    var query_range = raw_query_text_from_request_line(
        request_head, head_length
    )
    var query_start = query_range[0]
    var query_end = query_range[1]

    var limit_range = _absent_range()
    var page_range = _absent_range()
    var latitude_range = _absent_range()
    var longitude_range = _absent_range()
    var filters_range = _absent_range()
    var periods_range = _absent_range()

    var scan_position = query_start
    while scan_position < query_end:
        var ampersand_position = scan_position
        while (
            ampersand_position < query_end
            and Int(request_head[ampersand_position]) != CH_AMPERSAND
        ):
            ampersand_position += 1
        var equals_position = scan_position
        while (
            equals_position < ampersand_position
            and Int(request_head[equals_position]) != CH_EQUALS
        ):
            equals_position += 1
        var key_length = equals_position - scan_position
        var value_start = equals_position + 1
        var value_length = ampersand_position - value_start

        if value_length > 0:
            if _query_key_is(request_head, scan_position, key_length, "limit"):
                limit_range = _RequestParamRange(value_start, value_length)
            elif _query_key_is(request_head, scan_position, key_length, "page"):
                page_range = _RequestParamRange(value_start, value_length)
            elif _query_key_is(request_head, scan_position, key_length, "lat"):
                latitude_range = _RequestParamRange(value_start, value_length)
            elif _query_key_is(request_head, scan_position, key_length, "lng"):
                longitude_range = _RequestParamRange(value_start, value_length)
            elif _query_key_is(
                request_head, scan_position, key_length, "filters"
            ):
                filters_range = _RequestParamRange(value_start, value_length)
            elif _query_key_is(
                request_head, scan_position, key_length, "periods"
            ):
                periods_range = _RequestParamRange(value_start, value_length)
        scan_position = ampersand_position + 1

    if not limit_range.absent():
        var parsed_value = _parse_whole_number_strict(
            request_head + limit_range.offset, limit_range.length
        )
        if parsed_value[1]:
            request.limit = _clamp_limit(Int(parsed_value[0]))

    if not page_range.absent():
        var parsed_value = _parse_whole_number_strict(
            request_head + page_range.offset, page_range.length
        )
        if parsed_value[1]:
            request.skip = _page_skip(Int(parsed_value[0]), request.limit)

    if not latitude_range.absent():
        request.lat = _parse_clamped_degrees_from_bytes(
            request_head + latitude_range.offset,
            latitude_range.length,
            LAT_LIMIT_DEGREES,
        )
    if not longitude_range.absent():
        request.lng = _parse_clamped_degrees_from_bytes(
            request_head + longitude_range.offset,
            longitude_range.length,
            LNG_LIMIT_DEGREES,
        )

    request.has_geo = not (request.lat == 0.0 and request.lng == 0.0)

    if not filters_range.absent():
        parse_filter_ids_from_bytes(
            request_head + filters_range.offset,
            filters_range.length,
            request.filters,
        )
    if not periods_range.absent():
        parse_period_letters_from_bytes(
            request_head + periods_range.offset,
            periods_range.length,
            request.periods,
        )


def _clamp_limit(limit_value: Int) -> Int:

    if limit_value < 1:
        return 1
    if limit_value > MAX_LIMIT:
        return MAX_LIMIT
    return limit_value


def _page_skip(page: Int, limit: Int) -> Int:

    var page_number = page
    if page_number < 1:
        page_number = 1
    if page_number > 1:
        return (page_number - 1) * limit
    return 0


comptime CH_AMPERSAND = 38
comptime CH_EQUALS = 61


def _filters_join_from_value(
    ref filters_value: Value, mut joined_characters: List[UInt8]
) -> Bool:

    if not filters_value.is_array():
        return False
    ref filters_array = filters_value.array()
    var is_first = True
    for element_index in range(len(filters_array)):
        ref element_value = filters_array[element_index]
        if not element_value.is_int():
            return False
        var id_value = element_value.int()
        if not is_first:
            joined_characters.append(UInt8(CH_PIPE))
        is_first = False
        if id_value < 0:
            joined_characters.append(UInt8(CH_MINUS))
            id_value = -id_value
        _append_decimal_digit_characters(joined_characters, id_value)
    return True


def _string_range_of(ref value: Value, mut keep: String) -> Tuple[Int, Int]:

    keep = String(value.string())
    var text_data = keep.as_bytes()
    return (Int(text_data.unsafe_ptr()), len(text_data))


def _bind_body(
    body: BytePtr, body_length: Int, mut request: NearbyRequest
) -> Bool:

    if body_length <= 0:
        return False
    var parsed_body = parse_json_body(body, body_length)
    if not parsed_body.ok:
        return False

    var text = String(
        unsafe_from_utf8=Span[Byte](unsafe_ptr=body, length=body_length)
    )
    var parsed = try_parse(text)
    if not parsed:
        return False

    var filters_pointer = body
    var filters_length = RANGE_ABSENT
    var periods_pointer = body
    var periods_length = RANGE_ABSENT
    var shape_ok = True
    var joined_filter_characters = List[UInt8]()
    var filters_keep = String("")
    var periods_keep = String("")

    try:
        ref root = parsed.value()
        if not root.is_object():
            return False
        for key in root.object():
            var key_text = String(key)
            if key_text == "filters":
                ref filters_value = root[key_text]
                if filters_value.is_null():
                    continue
                if _filters_join_from_value(
                    filters_value, joined_filter_characters
                ):
                    if len(joined_filter_characters) > 0:
                        filters_pointer = BytePtr(
                            unsafe_from_address=Int(
                                joined_filter_characters.unsafe_ptr()
                            )
                        )
                        filters_length = len(joined_filter_characters)
                    else:

                        filters_length = RANGE_ABSENT
                elif filters_value.is_string():
                    var filters_string_range = _string_range_of(
                        filters_value, filters_keep
                    )
                    filters_pointer = BytePtr(
                        unsafe_from_address=filters_string_range[0]
                    )
                    filters_length = filters_string_range[1]
                else:

                    shape_ok = False
            elif key_text == "periods":
                ref periods_value = root[key_text]
                if periods_value.is_null():
                    continue
                if periods_value.is_string():
                    var periods_string_range = _string_range_of(
                        periods_value, periods_keep
                    )
                    periods_pointer = BytePtr(
                        unsafe_from_address=periods_string_range[0]
                    )
                    periods_length = periods_string_range[1]
                else:
                    shape_ok = False
    except:
        return False
    if not shape_ok:
        return False

    request.limit = _clamp_limit(parsed_body.limit)
    request.skip = _page_skip(parsed_body.page, request.limit)
    request.lat = _clamp_degrees_to_limit(parsed_body.lat, LAT_LIMIT_DEGREES)
    request.lng = _clamp_degrees_to_limit(parsed_body.lng, LNG_LIMIT_DEGREES)
    request.has_geo = not (request.lat == 0.0 and request.lng == 0.0)
    if filters_length >= 0:
        parse_filter_ids_from_bytes(
            filters_pointer, filters_length, request.filters
        )
    if periods_length >= 0:
        parse_period_letters_from_bytes(
            periods_pointer, periods_length, request.periods
        )
    return True


def bind_nearby_request(
    method_code: UInt8,
    request_head: BytePtr,
    head_length: Int,
    body: BytePtr,
    body_length: Int,
) -> NearbyRequest:

    var request = NearbyRequest()
    if method_code == METHOD_QUERY:
        if _bind_body(body, body_length, request):
            return request^

        _bind_query_string(request_head, head_length, request)
        return request^
    _bind_query_string(request_head, head_length, request)
    return request^
