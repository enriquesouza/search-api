from mojoflask import BytePtr

from mojosearch.web.numeric_core import (
    _append_decimal_digit_characters,
    _clamp_degrees_to_limit,
    _is_ascii_digit_character,
    _parse_clamped_degrees_from_bytes,
    _parse_decimal_number_full,
    _parse_int32_strict,
    _parse_whole_number_strict,
    days_since_epoch_for_date_negative_era_twin,
    parse_filter_ids_from_bytes,
    parse_period_letters_from_bytes,
    parse_postgres_timestamp_nearby_bytes,
)


comptime CH_PIPE = 124


def bytes_pointer_of(imm text: String) -> BytePtr:

    var text_bytes = text.as_bytes()
    return BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr()))


def bytes_length_of(imm text: String) -> Int:

    return len(text.as_bytes())


def fail(detail: String) raises -> None:

    raise Error("numeric-core probe failed: " + detail)


def fail_unless_whole_number_equals(
    imm input_text: String,
    expected_value: Int64,
    expected_was_parsed: Bool,
    probe_name: String,
) raises:

    var text_bytes = input_text.as_bytes()
    var parsed = _parse_whole_number_strict(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
    )
    if parsed[0] != expected_value or parsed[1] != expected_was_parsed:
        fail(
            probe_name
            + " got "
            + String(parsed[0])
            + "/"
            + String(parsed[1])
        )


def fail_unless_int32_fence_equals(
    imm input_text: String, expected_was_parsed: Bool, probe_name: String
) raises:

    var text_bytes = input_text.as_bytes()
    var parsed = _parse_int32_strict(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
    )
    if parsed[1] != expected_was_parsed:
        fail(probe_name + " got accepted=" + String(parsed[1]))


def fail_unless_decimal_near(
    imm input_text: String, expected_value: Float64, probe_name: String
) raises:

    var text_bytes = input_text.as_bytes()
    var parsed = _parse_decimal_number_full(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
    )
    var difference = parsed[0] - expected_value
    if difference < 0:
        difference = -difference
    if not parsed[1] or difference > 0.000000001:
        fail(probe_name + " got " + String(parsed[0]) + "/" + String(parsed[1]))


def fail_unless_decimal_rejected(imm input_text: String, probe_name: String) raises:

    var text_bytes = input_text.as_bytes()
    var parsed = _parse_decimal_number_full(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
    )
    if parsed[1]:
        fail(probe_name + " accepted " + input_text)


def fail_unless_degrees_near(
    imm input_text: String,
    limit: Float64,
    expected_value: Float64,
    probe_name: String,
) raises:

    var text_bytes = input_text.as_bytes()
    var parsed_value = _parse_clamped_degrees_from_bytes(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
        limit,
    )
    var difference = parsed_value - expected_value
    if difference < 0:
        difference = -difference
    if difference > 0.000000001:
        fail(probe_name + " got " + String(parsed_value))


def filter_ids_text_of(imm values: List[Int32]) -> String:

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


def period_letters_text_of(imm values: List[UInt8]) -> String:

    var characters = List[UInt8]()
    for letter in values:
        characters.append(letter)
    return String(
        unsafe_from_utf8=Span[Byte](
            unsafe_ptr=characters.unsafe_ptr(), length=len(characters)
        )
    )


def fail_unless_filter_ids_parse_to(
    imm input_text: String, expected_text: String, probe_name: String
) raises:

    var parsed_ids = List[Int32]()
    var text_bytes = input_text.as_bytes()
    parse_filter_ids_from_bytes(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
        parsed_ids,
    )
    var actual_text = filter_ids_text_of(parsed_ids)
    if actual_text != expected_text:
        fail(probe_name + " got [" + actual_text + "] want [" + expected_text + "]")


def fail_unless_period_letters_parse_to(
    imm input_text: String, expected_text: String, probe_name: String
) raises:

    var parsed_letters = List[UInt8]()
    var text_bytes = input_text.as_bytes()
    parse_period_letters_from_bytes(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
        parsed_letters,
    )
    var actual_text = period_letters_text_of(parsed_letters)
    if actual_text != expected_text:
        fail(probe_name + " got [" + actual_text + "] want [" + expected_text + "]")


def fail_unless_timestamp_micros_equal(
    imm input_text: String, expected_micros: Int64, probe_name: String
) raises:

    var text_bytes = input_text.as_bytes()
    var parsed_micros = parse_postgres_timestamp_nearby_bytes(
        BytePtr(unsafe_from_address=Int(text_bytes.unsafe_ptr())),
        len(text_bytes),
    )
    if parsed_micros != expected_micros:
        fail(probe_name + " got " + String(parsed_micros))


def main() raises:

    fail_unless_whole_number_equals("12", 12, True, "whole-plain")
    fail_unless_whole_number_equals("-12", -12, True, "whole-negative")
    fail_unless_whole_number_equals("+5", 5, True, "whole-plus-sign")
    fail_unless_whole_number_equals("", 0, False, "whole-empty")
    fail_unless_whole_number_equals("-", 0, False, "whole-sign-only")
    fail_unless_whole_number_equals("+", 0, False, "whole-plus-only")
    fail_unless_whole_number_equals("12a", 0, False, "whole-trailing-letter")
    fail_unless_whole_number_equals(
        "9223372036854775807", 9223372036854775807, True, "whole-int64-max"
    )

    fail_unless_int32_fence_equals("2147483647", True, "int32-max-accepted")
    fail_unless_int32_fence_equals("2147483648", False, "int32-overflow-rejected")
    fail_unless_int32_fence_equals("-2147483648", True, "int32-min-accepted")
    fail_unless_int32_fence_equals("-2147483649", False, "int32-underflow-rejected")

    fail_unless_decimal_near("-23.5505", -23.5505, "decimal-plain-negative")
    fail_unless_decimal_near("55.0", 55.0, "decimal-plain-integer-float")
    fail_unless_decimal_near("0.0", 0.0, "decimal-zero")
    fail_unless_decimal_near("15e2", 0.15, "decimal-exponent-quirk-div-only")
    fail_unless_decimal_near("10.5e-1", 1.05, "decimal-fraction-exponent-sign-ignored")
    fail_unless_decimal_near("5.", 5.0, "decimal-trailing-dot")
    fail_unless_decimal_rejected("abc", "decimal-letters")
    fail_unless_decimal_rejected("", "decimal-empty")
    fail_unless_decimal_rejected("+", "decimal-plus-only")
    fail_unless_decimal_rejected("1.2.3", "decimal-double-dot")
    fail_unless_decimal_rejected("1e", "decimal-bare-exponent")

    fail_unless_degrees_near(" -23.5505 ", 90.0, -23.5505, "degrees-trimmed")
    fail_unless_degrees_near("10,20", 90.0, 10.0, "degrees-comma-pair-habit")
    fail_unless_degrees_near("95", 90.0, 0.0, "degrees-over-limit-folded")
    fail_unless_degrees_near("-95", 90.0, 0.0, "degrees-under-limit-folded")
    fail_unless_degrees_near("170", 180.0, 170.0, "degrees-longitude-accepted")
    fail_unless_degrees_near("abc", 90.0, 0.0, "degrees-letters-folded")
    fail_unless_degrees_near("", 90.0, 0.0, "degrees-empty-folded")

    var clamped_over = _clamp_degrees_to_limit(91.0, 90.0)
    var clamped_kept = _clamp_degrees_to_limit(-46.5, 90.0)
    if clamped_over != 0.0 or clamped_kept != -46.5:
        fail("clamp-degrees-direct")

    if not _is_ascii_digit_character(57) or _is_ascii_digit_character(58):
        fail("digit-character-bounds")
    if _is_ascii_digit_character(47):
        fail("digit-character-below-bounds")

    fail_unless_filter_ids_parse_to("7502|25", "7502|25", "filters-canonical")
    fail_unless_filter_ids_parse_to("5|0|6", "5|6", "filters-zero-dropped")
    fail_unless_filter_ids_parse_to("-5|7", "7", "filters-negative-dropped")
    fail_unless_filter_ids_parse_to("  7  ", "7", "filters-trimmed")
    fail_unless_filter_ids_parse_to("0", "", "filters-nil-law-zero")
    fail_unless_filter_ids_parse_to("-", "", "filters-nil-law-minus")
    fail_unless_filter_ids_parse_to("", "", "filters-nil-law-empty")
    fail_unless_filter_ids_parse_to("2147483648", "", "filters-int32-fence")

    var long_filters = List[String]()
    var long_filters_text = String("")
    for number in range(40):
        if number > 0:
            long_filters_text += "|"
        long_filters_text += String(number + 1)
    long_filters.append(long_filters_text)
    var thirty_two_text = String("")
    for number in range(32):
        if number > 0:
            thirty_two_text += "|"
        thirty_two_text += String(number + 1)
    fail_unless_filter_ids_parse_to(
        long_filters_text, thirty_two_text, "filters-cap-32"
    )

    var oversized_input = String("")
    for number in range(2050):
        oversized_input += "1"
    fail_unless_filter_ids_parse_to(oversized_input, "", "filters-max-len-nil")

    fail_unless_period_letters_parse_to(
        "M|h|H|d|D|S|m|Y|P|z|x|y", "MHDSYP", "periods-book-dedupe-probe"
    )
    fail_unless_period_letters_parse_to("m,d", "MD", "periods-comma-separator")
    fail_unless_period_letters_parse_to("Z", "", "periods-invalid-letter")
    fail_unless_period_letters_parse_to("", "", "periods-nil-law-empty")
    fail_unless_period_letters_parse_to("-", "", "periods-nil-law-minus")
    fail_unless_period_letters_parse_to("0", "", "periods-nil-law-zero")
    fail_unless_period_letters_parse_to(
        "h|d|s|m|y|p|H|D", "HDSMYP", "periods-cap-six"
    )

    fail_unless_timestamp_micros_equal(
        "2026-08-14 17:51:07.875448", 1786729867875448, "timestamp-micros"
    )
    fail_unless_timestamp_micros_equal(
        "2026-08-14T17:51:07", 1786729867000000, "timestamp-t-separator"
    )
    fail_unless_timestamp_micros_equal(
        "2026-08-14 17:51:07+03:00", 1786719067000000, "timestamp-offset"
    )
    fail_unless_timestamp_micros_equal(
        "1970-01-01 00:00:00", 0, "timestamp-epoch"
    )
    fail_unless_timestamp_micros_equal(
        "2000-02-29 23:59:59.999999", 951868799999999, "timestamp-leap-day"
    )
    fail_unless_timestamp_micros_equal(
        "0001-01-01 00:00:00", -62135596800000000, "timestamp-negative-era"
    )
    fail_unless_timestamp_micros_equal("2026", 0, "timestamp-too-short")

    if days_since_epoch_for_date_negative_era_twin(1970, 1, 1) != 0:
        fail("days-twin-epoch")
    if days_since_epoch_for_date_negative_era_twin(1969, 12, 31) != -1:
        fail("days-twin-day-before-epoch")
    if days_since_epoch_for_date_negative_era_twin(1, 1, 1) != -719162:
        fail("days-twin-proleptic-era")
    if days_since_epoch_for_date_negative_era_twin(2000, 2, 29) != 11016:
        fail("days-twin-leap-day")

    print("numeric_core selftest: ALL PASS")
