from mojoflask import (
    METHOD_GET,
    METHOD_POST,
    METHOD_QUERY,
    BytePtr,
)

from mojosearch.web.binding import (
    MAX_LIMIT,
    _bind_query_string,
    bind_nearby_request,
)
from mojosearch.web.market_code import market_code_from_request_head
from mojosearch.web.numeric_core import _append_decimal_digit_characters

from mojosearch.services.nearby_request import NearbyRequest


comptime CH_PIPE = 124


def bytes_pointer_of(imm text: String) -> BytePtr:

    var text_bytes = text.as_bytes()
    return BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr()))


def bytes_length_of(imm text: String) -> Int:

    return len(text.as_bytes())


def head_with_query(imm query_text: String) -> String:

    return (
        "GET /br/api/listings/nearby?"
        + query_text
        + " HTTP/1.1\r\nHost: probes\r\n\r\n"
    )


def query_body_head() -> String:

    return "POST /br/api/listings/nearby HTTP/1.1\r\nHost: probes\r\n\r\n"


def fail(detail: String) raises -> None:

    raise Error("binding probe failed: " + detail)


def bind_get_query(imm query_text: String) -> NearbyRequest:

    var absent_body_byte: UInt8 = 0
    var head_bytes = head_with_query(query_text).as_bytes()
    return bind_nearby_request(
        METHOD_GET,
        BytePtr(unsafe_from_address=Int(head_bytes.unsafe_ptr())),
        len(head_bytes),
        BytePtr(unsafe_from_address=Int(Pointer(to=absent_body_byte))),
        0,
    )


def bind_post_body(imm body_text: String) -> NearbyRequest:

    var head_bytes = query_body_head().as_bytes()
    var body_bytes = body_text.as_bytes()
    return bind_nearby_request(
        METHOD_QUERY,
        BytePtr(unsafe_from_address=Int(head_bytes.unsafe_ptr())),
        len(head_bytes),
        BytePtr(unsafe_from_address=Int(body_bytes.unsafe_ptr())),
        len(body_bytes),
    )


def filters_text_of(imm values: List[Int32]) -> String:

    var characters = List[UInt8]()
    var is_first = True
    for value in values:
        if not is_first:
            characters.append(UInt8(CH_PIPE))
        is_first = False
        _append_decimal_digit_characters(characters, Int64(value))
    return String(
        unsafe_from_utf8=Span[Byte](
            unsafe_ptr=characters.unsafe_ptr(), length=len(characters)
        )
    )


def periods_text_of(imm values: List[UInt8]) -> String:

    var characters = List[UInt8]()
    for letter in values:
        characters.append(letter)
    return String(
        unsafe_from_utf8=Span[Byte](
            unsafe_ptr=characters.unsafe_ptr(), length=len(characters)
        )
    )


def fail_unless_bound_fields_equal(
    imm bound_request: NearbyRequest,
    expected_limit: Int,
    expected_skip: Int,
    expected_latitude: Float64,
    expected_longitude: Float64,
    expected_has_geo: Bool,
    expected_filters_text: String,
    expected_periods_text: String,
    probe_name: String,
) raises:

    if bound_request.limit != expected_limit:
        fail(probe_name + " limit " + String(bound_request.limit))
    if bound_request.skip != expected_skip:
        fail(probe_name + " skip " + String(bound_request.skip))
    if bound_request.lat != expected_latitude:
        fail(probe_name + " lat " + String(bound_request.lat))
    if bound_request.lng != expected_longitude:
        fail(probe_name + " lng " + String(bound_request.lng))
    if bound_request.has_geo != expected_has_geo:
        fail(probe_name + " has_geo " + String(bound_request.has_geo))
    var actual_filters_text = filters_text_of(bound_request.filters)
    if actual_filters_text != expected_filters_text:
        fail(
            probe_name
            + " filters ["
            + actual_filters_text
            + "] want ["
            + expected_filters_text
            + "]"
        )
    var actual_periods_text = periods_text_of(bound_request.periods)
    if actual_periods_text != expected_periods_text:
        fail(
            probe_name
            + " periods ["
            + actual_periods_text
            + "] want ["
            + expected_periods_text
            + "]"
        )


def fail_unless_market_equals(
    imm request_line: String, expected_market: String, probe_name: String
) raises:

    var line_bytes = request_line.as_bytes()
    var resolved_market = market_code_from_request_head(
        BytePtr(unsafe_from_address=Int(line_bytes.unsafe_ptr())),
        len(line_bytes),
    )
    if resolved_market != expected_market:
        fail(probe_name + " got " + resolved_market)


def main() raises:

    var defaults = bind_get_query("")
    fail_unless_bound_fields_equal(
        defaults^, 12, 0, 0.0, 0.0, False, "", "", "defaults"
    )

    var canonical = bind_get_query(
        "limit=50&page=2&lat=-23.5505&lng=-46.6333&filters=7502|25&periods=M|h"
    )
    fail_unless_bound_fields_equal(
        canonical^,
        50,
        50,
        -23.5505,
        -46.6333,
        True,
        "7502|25",
        "MH",
        "canonical-combined",
    )

    var book_canonical_300 = bind_get_query("limit=300&page=1&filters=0")
    fail_unless_bound_fields_equal(
        book_canonical_300^, 300, 0, 0.0, 0.0, False, "", "", "book-canonical-300"
    )

    var clamped_low = bind_get_query("limit=0")
    fail_unless_bound_fields_equal(
        clamped_low^, 1, 0, 0.0, 0.0, False, "", "", "clamp-low-to-one"
    )

    var last_key_wins = bind_get_query("limit=0&limit=7")
    fail_unless_bound_fields_equal(
        last_key_wins^, 7, 0, 0.0, 0.0, False, "", "", "repeat-key-last-wins"
    )

    var page_below_one = bind_get_query("limit=10&page=0")
    fail_unless_bound_fields_equal(
        page_below_one^, 10, 0, 0.0, 0.0, False, "", "", "page-below-one-no-skip"
    )

    var clamped_high = bind_get_query("limit=999")
    fail_unless_bound_fields_equal(
        clamped_high^, MAX_LIMIT, 0, 0.0, 0.0, False, "", "", "clamp-high"
    )

    var invalid_limit = bind_get_query("limit=abc")
    fail_unless_bound_fields_equal(
        invalid_limit^, 12, 0, 0.0, 0.0, False, "", "", "invalid-limit-keeps-default"
    )

    var page_window = bind_get_query("limit=10&page=3")
    fail_unless_bound_fields_equal(
        page_window^, 10, 20, 0.0, 0.0, False, "", "", "page-skip-window"
    )

    var geo_pair = bind_get_query("lat=10,20&lng=-170")
    fail_unless_bound_fields_equal(
        geo_pair^, 12, 0, 10.0, -170.0, True, "", "", "geo-comma-pair-habit"
    )

    var geo_out_of_range = bind_get_query("lat=95&lng=200")
    fail_unless_bound_fields_equal(
        geo_out_of_range^, 12, 0, 0.0, 0.0, False, "", "", "geo-out-of-range-folded"
    )

    var longitude_inside_limit = bind_get_query("lat=95&lng=95")
    fail_unless_bound_fields_equal(
        longitude_inside_limit^,
        12,
        0,
        0.0,
        95.0,
        True,
        "",
        "",
        "longitude-95-inside-180-limit"
    )

    var empty_values = bind_get_query("lat=&filters=&periods=")
    fail_unless_bound_fields_equal(
        empty_values^, 12, 0, 0.0, 0.0, False, "", "", "empty-values-unset"
    )

    var filters_nil_minus = bind_get_query("filters=-")
    fail_unless_bound_fields_equal(
        filters_nil_minus^, 12, 0, 0.0, 0.0, False, "", "", "filters-nil-law-minus"
    )

    var periods_book_dedupe = bind_get_query("periods=M|h|H|d|D|S|m|Y|P|z|x|y")
    fail_unless_bound_fields_equal(
        periods_book_dedupe^,
        12,
        0,
        0.0,
        0.0,
        False,
        "",
        "MHDSYP",
        "periods-book-dedupe-probe",
    )

    var combined_page_two = bind_get_query(
        "page=2&filters=5|0|6&periods=h|z|D"
    )
    fail_unless_bound_fields_equal(
        combined_page_two^,
        12,
        12,
        0.0,
        0.0,
        False,
        "5|6",
        "HD",
        "combined-filters-periods-page-2",
    )

    var latitude_alias_ignored = bind_get_query("latitude=10&longitude=20")
    fail_unless_bound_fields_equal(
        latitude_alias_ignored^,
        12,
        0,
        0.0,
        0.0,
        False,
        "",
        "",
        "latitude-alias-ignored-on-query-line"
    )

    var body_canonical = bind_post_body(
        '{"limit":50,"page":2,"latitude":-23.5,"longitude":-46.6,'
        '"filters":[7502,25,-3],"periods":"h|s"}'
    )
    fail_unless_bound_fields_equal(
        body_canonical^,
        50,
        50,
        -23.5,
        -46.6,
        True,
        "7502|25",
        "HS",
        "query-body-canonical",
    )

    var body_filters_empty_array = bind_post_body(
        '{"filters":[],"latitude":-23.5}'
    )
    fail_unless_bound_fields_equal(
        body_filters_empty_array^,
        12,
        0,
        -23.5,
        0.0,
        True,
        "",
        "",
        "query-body-empty-filters-array"
    )

    var body_null_filters = bind_post_body('{"filters":null,"limit":5}')
    fail_unless_bound_fields_equal(
        body_null_filters^, 5, 0, 0.0, 0.0, False, "", "", "query-body-null-filters"
    )

    var body_string_filters = bind_post_body('{"filters":"7|8"}')
    fail_unless_bound_fields_equal(
        body_string_filters^, 12, 0, 0.0, 0.0, False, "7|8", "", "query-body-string-filters"
    )

    var body_bad_shape_falls_back = bind_nearby_request(
        METHOD_QUERY,
        BytePtr(
            unsafe_from_address=Int(
                head_with_query("lat=-12.5&limit=9").as_bytes().unsafe_ptr()
            )
        ),
        bytes_length_of(head_with_query("lat=-12.5&limit=9")),
        bytes_pointer_of('{"filters":[1,"x"]}'),
        bytes_length_of('{"filters":[1,"x"]}'),
    )
    fail_unless_bound_fields_equal(
        body_bad_shape_falls_back^,
        9,
        0,
        -12.5,
        0.0,
        True,
        "",
        "",
        "body-bad-shape-falls-back-to-query"
    )

    var body_unparseable_falls_back = bind_nearby_request(
        METHOD_QUERY,
        BytePtr(
            unsafe_from_address=Int(head_with_query("limit=8").as_bytes().unsafe_ptr())
        ),
        bytes_length_of(head_with_query("limit=8")),
        bytes_pointer_of("{not json"),
        bytes_length_of("{not json"),
    )
    fail_unless_bound_fields_equal(
        body_unparseable_falls_back^,
        8,
        0,
        0.0,
        0.0,
        False,
        "",
        "",
        "body-unparseable-falls-back-to-query"
    )

    var get_ignores_body = bind_nearby_request(
        METHOD_GET,
        BytePtr(
            unsafe_from_address=Int(head_with_query("limit=4").as_bytes().unsafe_ptr())
        ),
        bytes_length_of(head_with_query("limit=4")),
        bytes_pointer_of('{"limit":300}'),
        bytes_length_of('{"limit":300}'),
    )
    fail_unless_bound_fields_equal(
        get_ignores_body^, 4, 0, 0.0, 0.0, False, "", "", "get-ignores-body"
    )

    var post_uses_query_when_method_differs = bind_nearby_request(
        METHOD_POST,
        BytePtr(
            unsafe_from_address=Int(head_with_query("limit=6").as_bytes().unsafe_ptr())
        ),
        bytes_length_of(head_with_query("limit=6")),
        bytes_pointer_of('{"limit":300}'),
        bytes_length_of('{"limit":300}'),
    )
    fail_unless_bound_fields_equal(
        post_uses_query_when_method_differs^,
        6,
        0,
        0.0,
        0.0,
        False,
        "",
        "",
        "non-query-method-uses-query-line"
    )

    var rebound_by_query_string = NearbyRequest()
    var head_bytes = head_with_query("limit=21&periods=p").as_bytes()
    _bind_query_string(
        BytePtr(unsafe_from_address=Int(head_bytes.unsafe_ptr())),
        len(head_bytes),
        rebound_by_query_string,
    )
    fail_unless_bound_fields_equal(
        rebound_by_query_string^, 21, 0, 0.0, 0.0, False, "", "P", "bind-query-string-direct"
    )

    fail_unless_market_equals(
        "GET /br/api/listings/nearby?x=1 HTTP/1.1", "br", "market-br"
    )
    fail_unless_market_equals(
        "PUT /US/api/listings/nearby HTTP/1.1", "us", "market-us-case-folded"
    )
    fail_unless_market_equals(
        "GET /ar?x=1 HTTP/1.1", "ar", "market-ar-question-terminator"
    )
    fail_unless_market_equals("GET /long/x HTTP/1.1", "other", "market-long-segment")
    fail_unless_market_equals("GET / HTTP/1.1", "other", "market-root")
    fail_unless_market_equals("GET /bq/x HTTP/1.1", "other", "market-unknown-code")
    fail_unless_market_equals("garbage", "other", "market-no-space")

    print("binding selftest: ALL PASS")
