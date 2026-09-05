"""mojosearch.web.numeric_core — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby/_numeric_ascii_core.mojo
"""

from mojoflask import BytePtr

from mojolinq import any


comptime INT32_MAX = 2147483647

comptime INT32_MIN = -2147483648

comptime FILTER_CAP = 32


comptime PERIOD_CAP = 6


comptime FILTERS_MAX_LEN = 2048


comptime ASCII_DIGIT_LO = 48
comptime ASCII_DIGIT_HI = 57
comptime CH_PLUS = 43
comptime CH_MINUS = 45
comptime CH_DOT = 46
comptime CH_ZERO = 48
comptime CH_EXPONENT_LOWER = 101
comptime CH_EXPONENT_UPPER = 69
comptime ASC_LOWER_LO = 97
comptime ASC_LOWER_HI = 122
comptime ASC_CASE_DELTA = 32
comptime ASC_UPPER_D = 68
comptime ASC_UPPER_H = 72
comptime ASC_UPPER_M = 77
comptime ASC_UPPER_P = 80
comptime ASC_UPPER_S = 83
comptime ASC_UPPER_Y = 89
comptime CH_COMMA = 44
comptime CH_PIPE = 124


def _trim_space_tab_newline_carriage_return_range(
    input_pointer: BytePtr, input_length: Int
) -> Tuple[Int, Int]:

    var start_index = 0
    var end_index = input_length
    while start_index < end_index:
        var character_value = Int(input_pointer[start_index])
        if (
            character_value == 32
            or character_value == 9
            or character_value == 10
            or character_value == 13
        ):
            start_index += 1
        else:
            break
    while end_index > start_index:
        var character_value = Int(input_pointer[end_index - 1])
        if (
            character_value == 32
            or character_value == 9
            or character_value == 10
            or character_value == 13
        ):
            end_index -= 1
        else:
            break
    return (start_index, end_index)


def _is_ascii_digit_character(character_value: Int) -> Bool:

    return (
        character_value >= ASCII_DIGIT_LO and character_value <= ASCII_DIGIT_HI
    )


def _parse_whole_number_strict(
    input_pointer: BytePtr, input_length: Int
) -> Tuple[Int64, Bool]:

    var scan_index = 0
    var is_negative = False
    if input_length == 0:
        return (0, False)
    if Int(input_pointer[0]) == CH_MINUS:
        is_negative = True
        scan_index = 1
    elif Int(input_pointer[0]) == CH_PLUS:
        scan_index = 1
    if scan_index == input_length:
        return (0, False)
    var accumulated_value: Int64 = 0
    while scan_index < input_length:
        var digit_value = Int(input_pointer[scan_index])
        if not _is_ascii_digit_character(digit_value):
            return (0, False)
        accumulated_value = accumulated_value * 10 + Int64(
            digit_value - ASCII_DIGIT_LO
        )
        scan_index += 1
    return (-accumulated_value if is_negative else accumulated_value, True)


def _parse_int32_strict(
    input_pointer: BytePtr, input_length: Int
) -> Tuple[Int64, Bool]:

    var parsed = _parse_whole_number_strict(input_pointer, input_length)
    if not parsed[1] or parsed[0] > INT32_MAX or parsed[0] < INT32_MIN:
        return (0, False)
    return parsed


def _append_decimal_digit_characters(mut out: List[UInt8], magnitude: Int64):

    var digits = List[UInt8]()
    var remaining_magnitude = magnitude
    if remaining_magnitude == 0:
        digits.append(UInt8(ASCII_DIGIT_LO))
    while remaining_magnitude > 0:
        digits.append(UInt8(ASCII_DIGIT_LO + remaining_magnitude % 10))
        remaining_magnitude //= 10
    var digit_index = len(digits) - 1
    while digit_index >= 0:
        out.append(digits[digit_index])
        digit_index -= 1


def _parse_decimal_number_full(
    input_pointer: BytePtr, input_length: Int
) -> Tuple[Float64, Bool]:

    var is_negative = False
    var scan_index = 0
    if input_length == 0:
        return (0.0, False)
    if Int(input_pointer[0]) == CH_MINUS:
        is_negative = True
        scan_index = 1
    elif Int(input_pointer[0]) == CH_PLUS:
        scan_index = 1
    var accumulated_value = 0.0
    var seen_digit = False
    var fraction_digit_count = 0
    var seen_decimal_point = False
    while scan_index < input_length:
        var digit_value = Int(input_pointer[scan_index])
        if _is_ascii_digit_character(digit_value):
            accumulated_value = accumulated_value * 10 + Float64(
                digit_value - ASCII_DIGIT_LO
            )
            if seen_decimal_point:
                fraction_digit_count += 1
            seen_digit = True
            scan_index += 1
        elif digit_value == CH_DOT and not seen_decimal_point:
            seen_decimal_point = True
            scan_index += 1
        else:
            break
    if not seen_digit:
        return (0.0, False)
    var exponent_value = 0
    var exponent_is_negative = False
    if scan_index < input_length and (
        Int(input_pointer[scan_index]) == CH_EXPONENT_LOWER
        or Int(input_pointer[scan_index]) == CH_EXPONENT_UPPER
    ):

        scan_index += 1
        if scan_index < input_length and (
            Int(input_pointer[scan_index]) == CH_MINUS
        ):
            exponent_is_negative = True
            scan_index += 1
        elif scan_index < input_length and (
            Int(input_pointer[scan_index]) == CH_PLUS
        ):
            scan_index += 1
        if scan_index == input_length:
            return (0.0, False)
        while scan_index < input_length:
            var exponent_character = Int(input_pointer[scan_index])
            if not _is_ascii_digit_character(exponent_character):
                return (0.0, False)
            exponent_value = exponent_value * 10 + (
                exponent_character - ASCII_DIGIT_LO
            )
            scan_index += 1
    if scan_index != input_length:
        return (0.0, False)

    var digit_shift = exponent_value + fraction_digit_count
    var scale = 1.0
    for _ in range(digit_shift):
        scale *= 10.0
    var parsed_number = accumulated_value / scale
    return (-parsed_number if is_negative else parsed_number, True)


def _parse_clamped_degrees_from_bytes(
    input_pointer: BytePtr, input_length: Int, limit: Float64
) -> Float64:

    var trimmed_range = _trim_space_tab_newline_carriage_return_range(
        input_pointer, input_length
    )
    var scan_pointer = input_pointer + trimmed_range[0]
    var scan_length = trimmed_range[1] - trimmed_range[0]
    var comma = 0
    while comma < scan_length and Int(scan_pointer[comma]) != CH_COMMA:
        comma += 1
    if comma < scan_length:
        scan_length = comma
    var inner_trimmed_range = _trim_space_tab_newline_carriage_return_range(
        scan_pointer, scan_length
    )
    scan_pointer += inner_trimmed_range[0]
    scan_length = inner_trimmed_range[1] - inner_trimmed_range[0]
    var parsed = _parse_decimal_number_full(scan_pointer, scan_length)
    if not parsed[1]:
        return 0.0
    return _clamp_degrees_to_limit(parsed[0], limit)


def _clamp_degrees_to_limit(value: Float64, limit: Float64) -> Float64:

    if value < -limit or value > limit:
        return 0.0
    return value


def parse_filter_ids_from_bytes(
    input_pointer: BytePtr, input_length: Int, mut out: List[Int32]
):

    out.clear()
    var trimmed_range = _trim_space_tab_newline_carriage_return_range(
        input_pointer, input_length
    )
    var scan_pointer = input_pointer + trimmed_range[0]
    var scan_length = trimmed_range[1] - trimmed_range[0]
    if scan_length == 0 or scan_length > FILTERS_MAX_LEN:
        return
    if scan_length == 1 and (
        Int(scan_pointer[0]) == CH_MINUS or Int(scan_pointer[0]) == CH_ZERO
    ):
        return
    var part_start = 0
    while part_start <= scan_length:
        var part_end = part_start
        while part_end < scan_length and Int(scan_pointer[part_end]) != CH_PIPE:
            part_end += 1
        var trimmed_part_range = _trim_space_tab_newline_carriage_return_range(
            scan_pointer + part_start, part_end - part_start
        )
        var part_pointer = scan_pointer + part_start + trimmed_part_range[0]
        var part_length = trimmed_part_range[1] - trimmed_part_range[0]

        var is_zero = part_length == 1 and Int(part_pointer[0]) == CH_ZERO
        var parsed_id_value = _parse_int32_strict(part_pointer, part_length)
        if (
            part_length > 0
            and not is_zero
            and parsed_id_value[1]
            and parsed_id_value[0] > 0
        ):
            out.append(Int32(parsed_id_value[0]))
            if len(out) >= FILTER_CAP:
                return
        part_start = part_end + 1


def _ascii_uppercase_value(byte_value: Int) -> Int:

    if byte_value >= ASC_LOWER_LO and byte_value <= ASC_LOWER_HI:
        return byte_value - ASC_CASE_DELTA
    return byte_value


def _is_period_letter_value(uppercase_value: Int) -> Bool:

    return (
        uppercase_value == ASC_UPPER_D
        or uppercase_value == ASC_UPPER_H
        or uppercase_value == ASC_UPPER_M
        or uppercase_value == ASC_UPPER_P
        or uppercase_value == ASC_UPPER_S
        or uppercase_value == ASC_UPPER_Y
    )


def parse_period_letters_from_bytes(
    input_pointer: BytePtr, input_length: Int, mut out: List[UInt8]
):

    out.clear()
    var trimmed_range = _trim_space_tab_newline_carriage_return_range(
        input_pointer, input_length
    )
    var scan_pointer = input_pointer + trimmed_range[0]
    var scan_length = trimmed_range[1] - trimmed_range[0]
    if scan_length == 0:
        return
    if scan_length == 1 and (
        Int(scan_pointer[0]) == CH_MINUS or Int(scan_pointer[0]) == CH_ZERO
    ):
        return
    var part_start = 0
    while part_start <= scan_length:
        var part_end = part_start
        var separator_found = False
        while part_end < scan_length:
            var separator_value = Int(scan_pointer[part_end])
            if separator_value == CH_PIPE or separator_value == CH_COMMA:
                separator_found = True
                break
            part_end += 1
        var trimmed_part_range = _trim_space_tab_newline_carriage_return_range(
            scan_pointer + part_start, part_end - part_start
        )
        var part_pointer = scan_pointer + part_start + trimmed_part_range[0]
        var part_length = trimmed_part_range[1] - trimmed_part_range[0]
        if part_length == 1:
            var uppercase_value = _ascii_uppercase_value(Int(part_pointer[0]))

            def period_letter_already_seen(
                existing_period_letter: UInt8,
            ) {uppercase_value} -> Bool:
                return Int(existing_period_letter) == uppercase_value

            var already_seen = any(out, period_letter_already_seen)
            if not already_seen and _is_period_letter_value(uppercase_value):
                out.append(UInt8(uppercase_value))
                if len(out) >= PERIOD_CAP:
                    return
        if not separator_found:
            return
        part_start = part_end + 1


def _read_digit_run_as_number(
    input_pointer: BytePtr, start_index: Int, digit_count: Int
) -> Int64:
    var accumulated_value: Int64 = 0
    for offset_index in range(digit_count):
        var digit_value = Int(input_pointer[start_index + offset_index])
        if digit_value < ASCII_DIGIT_LO or digit_value > ASCII_DIGIT_HI:
            return -1
        accumulated_value = accumulated_value * 10 + Int64(
            digit_value - ASCII_DIGIT_LO
        )
    return accumulated_value


def days_since_epoch_for_date_negative_era_twin(
    input_year: Int64, month_value: Int, day_value: Int
) -> Int64:

    var year_value = input_year
    if month_value <= 2:
        year_value -= 1
    var era = year_value // 400
    if year_value < 0 and year_value % 400 != 0:
        era -= 1
    var year_of_era = year_value - era * 400
    var shifted_month_index = (month_value + 9) % 12
    var day_of_year = Int64(
        (153 * shifted_month_index + 2) // 5 + day_value - 1
    )
    var day_of_era = (
        year_of_era * 365 + year_of_era // 4 - year_of_era // 100 + day_of_year
    )
    return era * 146097 + day_of_era - 719468


def parse_postgres_timestamp_nearby_bytes(
    input_pointer: BytePtr, input_length: Int
) -> Int64:

    var trimmed_range = _trim_space_tab_newline_carriage_return_range(
        input_pointer, input_length
    )
    var text_pointer = input_pointer + trimmed_range[0]
    var text_length = trimmed_range[1] - trimmed_range[0]
    if text_length < 19:
        return 0
    var year_value = _read_digit_run_as_number(text_pointer, 0, 4)
    var month_value = _read_digit_run_as_number(text_pointer, 5, 2)
    var day_value = _read_digit_run_as_number(text_pointer, 8, 2)
    var hour_value = _read_digit_run_as_number(text_pointer, 11, 2)
    var minute_value = _read_digit_run_as_number(text_pointer, 14, 2)
    var second_value = _read_digit_run_as_number(text_pointer, 17, 2)
    if (
        year_value < 0
        or month_value < 0
        or day_value < 0
        or hour_value < 0
        or minute_value < 0
        or second_value < 0
    ):
        return 0
    var micros: Int64 = 0
    var scan_position = 19
    if scan_position < text_length and Int(text_pointer[scan_position]) == 46:
        scan_position += 1
        var fraction_digit_count = 0
        while (
            scan_position + fraction_digit_count < text_length
            and Int(text_pointer[scan_position + fraction_digit_count]) >= 48
            and Int(text_pointer[scan_position + fraction_digit_count]) <= 57
            and fraction_digit_count < 6
        ):
            fraction_digit_count += 1
        micros = _read_digit_run_as_number(
            text_pointer, scan_position, fraction_digit_count
        )
        if micros < 0:
            return 0
        var padding_digits = fraction_digit_count
        while padding_digits < 6:
            micros *= 10
            padding_digits += 1
        scan_position += fraction_digit_count
    var offset_seconds: Int64 = 0
    if scan_position < text_length and (
        Int(text_pointer[scan_position]) == 43
        or Int(text_pointer[scan_position]) == 45
    ):
        var sign: Int64 = 1
        if Int(text_pointer[scan_position]) == 45:
            sign = -1
        scan_position += 1
        var offset_hours = _read_digit_run_as_number(
            text_pointer, scan_position, 2
        )
        if offset_hours < 0:
            return 0
        scan_position += 2
        var offset_minutes: Int64 = 0
        if (
            scan_position < text_length
            and Int(text_pointer[scan_position]) == 58
        ):
            offset_minutes = _read_digit_run_as_number(
                text_pointer, scan_position + 1, 2
            )
            if offset_minutes < 0:
                return 0
        offset_seconds = sign * (offset_hours * 3600 + offset_minutes * 60)
    var days = days_since_epoch_for_date_negative_era_twin(
        year_value, Int(month_value), Int(day_value)
    )
    var total_seconds = (
        days * 86400
        + hour_value * 3600
        + minute_value * 60
        + second_value
        - offset_seconds
    )
    return total_seconds * 1_000_000 + micros
