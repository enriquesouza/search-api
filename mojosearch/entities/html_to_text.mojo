"""Mojosearch entities html_to_text — the frozen HTML-to-text scanner
(tag skipping, raw-text elements, named and numeric character references,
Windows-1252 numeric fallbacks), moved verbatim from the application with
byte behavior frozen.

origin: alugue-mojo-api utils/html_to_text.mojo
"""

from mojoflask import free_bytes

from mojoflask.text import utf8_rune_at

from mojoserde.buf import ByteBuf, BytePtr, retracked

from mojosearch.entities.entities_tbl import (
    ENT_COUNT,
    ENT_NAME_W,
    ENT_NAMES,
    ENT_VALUES,
    LONGEST_WITHOUT_SEMI,
)

from mojoflask.text import lowercase_ascii_letters_only


def _is_whitespace_byte(character_code: Int) -> Bool:
    return (
        character_code == 32
        or character_code == 9
        or character_code == 10
        or character_code == 11
        or character_code == 12
        or character_code == 13
    )


def _is_ascii_letter(character_code: Int) -> Bool:
    return (character_code >= 97 and character_code <= 122) or (
        character_code >= 65 and character_code <= 90
    )


def _is_ascii_letter_or_digit(character_code: Int) -> Bool:
    return (
        (character_code >= 97 and character_code <= 122)
        or (character_code >= 65 and character_code <= 90)
        or (character_code >= 48 and character_code <= 57)
    )


def _lowercase_ascii_byte(character_code: Int) -> Int:
    if character_code >= 65 and character_code <= 90:
        return character_code + 32
    return character_code


def _range_equals_literal_case_insensitive(
    text_bytes: BytePtr, offset: Int, length: Int, literal: StaticString
) -> Bool:
    var literal_length = Int(literal.byte_length())
    if literal_length != length:
        return False
    var literal_bytes = literal.as_bytes()
    for byte_index in range(literal_length):
        if _lowercase_ascii_byte(Int(text_bytes[offset + byte_index])) != Int(
            literal_bytes[byte_index]
        ):
            return False
    return True


def _tag_name_activates_content_skip(
    text_bytes: BytePtr, name_start: Int, name_length: Int
) -> Bool:

    if name_length == 5 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "frame"
    ):
        return True
    if name_length == 8 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "frameset"
    ):
        return True
    if name_length == 6 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "iframe"
    ):
        return True
    if name_length == 7 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "noembed"
    ):
        return True
    if name_length == 8 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "noframes"
    ):
        return True
    if name_length == 7 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "noscript"
    ):
        return True
    if name_length == 7 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "nostyle"
    ):
        return True
    if name_length == 6 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "object"
    ):
        return True
    if name_length == 5 and _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, "title"
    ):
        return True
    return False


def _tag_name_equals_literal(
    text_bytes: BytePtr,
    name_start: Int,
    name_length: Int,
    literal: StaticString,
) -> Bool:
    return _range_equals_literal_case_insensitive(
        text_bytes, name_start, name_length, literal
    )


def _lowercase_tag_name(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> String:

    var view = String(
        unsafe_from_utf8=Span(
            unsafe_ptr=text_bytes + start_index, length=end_index - start_index
        )
    )
    return lowercase_ascii_letters_only(view)


def _literal_byte_pointer(literal: StaticString) -> BytePtr:
    var literal_bytes = literal.as_bytes()
    return BytePtr(unsafe_from_address=Int(literal_bytes.unsafe_ptr()))


def _parse_six_hex_digits(byte_pointer: BytePtr) -> Int:
    var value = 0
    for digit_index in range(6):
        var character_code = Int(byte_pointer[digit_index])
        var digit_value: Int
        if character_code >= 48 and character_code <= 57:
            digit_value = character_code - 48
        elif character_code >= 97 and character_code <= 102:
            digit_value = character_code - 87
        else:
            return -1
        value = value * 16 + digit_value
    return value


def _compare_query_against_entity_record(
    query_bytes: BytePtr, query_length: Int, record_bytes: BytePtr
) -> Int:

    var compare_limit = (
        query_length if query_length < ENT_NAME_W else ENT_NAME_W
    )
    for byte_index in range(compare_limit):
        var record_byte = Int(record_bytes[byte_index])
        if record_byte == 32:
            return 1
        var query_byte = Int(query_bytes[byte_index])
        if query_byte != record_byte:
            if query_byte < record_byte:
                return -1
            return 1
    if query_length <= ENT_NAME_W:
        if Int(record_bytes[query_length]) == 32:
            return 0
        return -1
    return 1


def find_entity_by_name(
    query_bytes: BytePtr, query_length: Int
) -> Tuple[Int, Int, Bool]:

    if query_length == 0 or query_length > ENT_NAME_W:
        return (0, 0, False)
    var entity_names_bytes = ENT_NAMES.as_bytes()
    var entity_values_bytes = ENT_VALUES.as_bytes()
    var names_pointer = BytePtr(
        unsafe_from_address=Int(entity_names_bytes.unsafe_ptr())
    )
    var values_pointer = BytePtr(
        unsafe_from_address=Int(entity_values_bytes.unsafe_ptr())
    )
    var low_index = 0
    var high_index = ENT_COUNT
    while low_index < high_index:
        var middle_index = (low_index + high_index) // 2
        var comparison_result = _compare_query_against_entity_record(
            query_bytes, query_length, names_pointer + middle_index * ENT_NAME_W
        )
        if comparison_result == 0:
            var first_codepoint = _parse_six_hex_digits(
                values_pointer + middle_index * 12
            )
            var second_codepoint = _parse_six_hex_digits(
                values_pointer + middle_index * 12 + 6
            )
            if first_codepoint < 0 or second_codepoint < 0:
                return (0, 0, False)
            return (first_codepoint, second_codepoint, True)
        if comparison_result < 0:
            high_index = middle_index
        else:
            low_index = middle_index + 1
    return (0, 0, False)


def _push_escaped_byte(mut output_buffer: ByteBuf, byte_value: Int):
    if byte_value == 38:
        output_buffer.push_str("&amp;")
    elif byte_value == 60:
        output_buffer.push_str("&lt;")
    elif byte_value == 62:
        output_buffer.push_str("&gt;")
    elif byte_value == 39:
        output_buffer.push_str("&#39;")
    elif byte_value == 34:
        output_buffer.push_str("&#34;")
    elif byte_value == 13:
        output_buffer.push_str("&#13;")
    else:
        output_buffer.push_u8(UInt8(byte_value))


def _push_escaped_codepoint(mut output_buffer: ByteBuf, codepoint: Int):
    var encoded_bytes = List[UInt8](capacity=4)
    if codepoint < 0x80:
        encoded_bytes.append(UInt8(codepoint))
    elif codepoint < 0x800:
        encoded_bytes.append(UInt8(0xC0 | (codepoint >> 6)))
        encoded_bytes.append(UInt8(0x80 | (codepoint & 0x3F)))
    elif codepoint < 0x10000:
        encoded_bytes.append(UInt8(0xE0 | (codepoint >> 12)))
        encoded_bytes.append(UInt8(0x80 | ((codepoint >> 6) & 0x3F)))
        encoded_bytes.append(UInt8(0x80 | (codepoint & 0x3F)))
    else:
        encoded_bytes.append(UInt8(0xF0 | (codepoint >> 18)))
        encoded_bytes.append(UInt8(0x80 | ((codepoint >> 12) & 0x3F)))
        encoded_bytes.append(UInt8(0x80 | ((codepoint >> 6) & 0x3F)))
        encoded_bytes.append(UInt8(0x80 | (codepoint & 0x3F)))
    for byte_index in range(len(encoded_bytes)):
        _push_escaped_byte(output_buffer, Int(encoded_bytes[byte_index]))


def _digit_value(character_code: Int, hex_mode: Bool) -> Int64:

    if hex_mode:
        if character_code >= 48 and character_code <= 57:
            return Int64(character_code - 48)
        elif character_code >= 97 and character_code <= 102:
            return Int64(character_code - 87)
        elif character_code >= 65 and character_code <= 70:
            return Int64(character_code - 55)
    else:
        if character_code >= 48 and character_code <= 57:
            return Int64(character_code - 48)
    return -1


def _decode_windows_1252_byte(byte_value: Int) -> Int:

    if byte_value == 0x00:
        return 0x20AC
    if byte_value == 0x01:
        return 0x81
    if byte_value == 0x02:
        return 0x201A
    if byte_value == 0x03:
        return 0x0192
    if byte_value == 0x04:
        return 0x201E
    if byte_value == 0x05:
        return 0x2026
    if byte_value == 0x06:
        return 0x2020
    if byte_value == 0x07:
        return 0x2021
    if byte_value == 0x08:
        return 0x02C6
    if byte_value == 0x09:
        return 0x2030
    if byte_value == 0x0A:
        return 0x0160
    if byte_value == 0x0B:
        return 0x2039
    if byte_value == 0x0C:
        return 0x0152
    if byte_value == 0x0D:
        return 0x8D
    if byte_value == 0x0E:
        return 0x017D
    if byte_value == 0x0F:
        return 0x8F
    if byte_value == 0x10:
        return 0x90
    if byte_value == 0x11:
        return 0x2018
    if byte_value == 0x12:
        return 0x2019
    if byte_value == 0x13:
        return 0x201C
    if byte_value == 0x14:
        return 0x201D
    if byte_value == 0x15:
        return 0x2022
    if byte_value == 0x16:
        return 0x2013
    if byte_value == 0x17:
        return 0x2014
    if byte_value == 0x18:
        return 0x02DC
    if byte_value == 0x19:
        return 0x2122
    if byte_value == 0x1A:
        return 0x0161
    if byte_value == 0x1B:
        return 0x203A
    if byte_value == 0x1C:
        return 0x0153
    if byte_value == 0x1D:
        return 0x9D
    if byte_value == 0x1E:
        return 0x017E
    return 0x0178


def _decode_numeric_reference(numeric_value: Int64) -> Int:

    if numeric_value >= 0x80 and numeric_value <= 0x9F:
        return _decode_windows_1252_byte(Int(numeric_value) - 0x80)
    if (
        numeric_value == 0
        or (numeric_value >= 0xD800 and numeric_value <= 0xDFFF)
        or numeric_value > 0x10FFFF
    ):
        return 0xFFFD
    return Int(numeric_value)


def _unescape_numeric_reference(
    text_bytes: BytePtr,
    ampersand_index: Int,
    end_index: Int,
    mut output_buffer: ByteBuf,
) -> Int:

    if ampersand_index + 2 >= end_index:
        output_buffer.push_str("&amp;")
        return 1
    var scan_index = ampersand_index + 2
    var hex_mode = False
    var prefix_character = Int(text_bytes[scan_index])
    if prefix_character == 120 or prefix_character == 88:
        hex_mode = True
        scan_index += 1
    var digits_start_index = scan_index
    var numeric_value: Int64 = 0
    while scan_index < end_index:
        var digit_value = _digit_value(Int(text_bytes[scan_index]), hex_mode)
        if digit_value < 0:
            break

        if numeric_value <= 0x10FFFF:
            var multiplier: Int64 = 16 if hex_mode else 10
            numeric_value = numeric_value * multiplier + digit_value
        scan_index += 1
    if scan_index == digits_start_index:
        output_buffer.push_str("&amp;")
        return 1
    if scan_index < end_index and Int(text_bytes[scan_index]) == 59:
        scan_index += 1
    _push_escaped_codepoint(
        output_buffer, _decode_numeric_reference(numeric_value)
    )
    return scan_index - ampersand_index


def _unescape_named_reference(
    text_bytes: BytePtr,
    ampersand_index: Int,
    end_index: Int,
    mut output_buffer: ByteBuf,
) -> Int:

    var scan_index = ampersand_index + 1
    while scan_index < end_index and _is_ascii_letter_or_digit(
        Int(text_bytes[scan_index])
    ):
        scan_index += 1
    if scan_index < end_index and Int(text_bytes[scan_index]) == 59:
        scan_index += 1
    var name_length = scan_index - ampersand_index - 1
    if name_length == 0:
        output_buffer.push_str("&amp;")
        return 1
    var matched_entity = find_entity_by_name(
        text_bytes + ampersand_index + 1, name_length
    )
    if matched_entity[2]:
        _push_escaped_codepoint(output_buffer, matched_entity[0])
        if matched_entity[1] != 0:
            _push_escaped_codepoint(output_buffer, matched_entity[1])
        return scan_index - ampersand_index

    var max_prefix_length = name_length - 1
    if max_prefix_length > LONGEST_WITHOUT_SEMI:
        max_prefix_length = LONGEST_WITHOUT_SEMI
    var prefix_length = max_prefix_length
    while prefix_length > 1:
        var prefix_match = find_entity_by_name(
            text_bytes + ampersand_index + 1, prefix_length
        )
        if prefix_match[2]:
            _push_escaped_codepoint(output_buffer, prefix_match[0])
            if prefix_match[1] != 0:
                _push_escaped_codepoint(output_buffer, prefix_match[1])
            return prefix_length + 1
        prefix_length -= 1
    output_buffer.push_str("&amp;")
    return 1


def _unescape_entity(
    text_bytes: BytePtr,
    ampersand_index: Int,
    end_index: Int,
    mut output_buffer: ByteBuf,
) -> Int:

    if ampersand_index + 1 >= end_index:
        output_buffer.push_str("&amp;")
        return 1
    if Int(text_bytes[ampersand_index + 1]) == 35:
        return _unescape_numeric_reference(
            text_bytes, ampersand_index, end_index, output_buffer
        )
    return _unescape_named_reference(
        text_bytes, ampersand_index, end_index, output_buffer
    )

    output_buffer.push_str("&amp;")
    return 1


def _convert_text_bytes_to_plain_text(
    text_bytes: BytePtr,
    start_index: Int,
    end_index: Int,
    unescape_entities: Bool,
    mut output_buffer: ByteBuf,
):

    var index = start_index
    while index < end_index:
        var character_code = Int(text_bytes[index])
        if unescape_entities and character_code == 38:
            index += _unescape_entity(
                text_bytes, index, end_index, output_buffer
            )
            continue
        if character_code == 13:
            output_buffer.push_u8(UInt8(10))
            if index + 1 < end_index and Int(text_bytes[index + 1]) == 10:
                index += 1
            index += 1
            continue
        _push_escaped_byte(output_buffer, character_code)
        index += 1


def _tag_name_end(text_bytes: BytePtr, start_index: Int, end_index: Int) -> Int:

    var index = start_index
    while index < end_index:
        var character_code = Int(text_bytes[index])
        if (
            _is_whitespace_byte(character_code)
            or character_code == 47
            or character_code == 62
        ):
            break
        index += 1
    return index


def _skip_tag_whitespace(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Int:

    var index = start_index
    while index < end_index and _is_whitespace_byte(Int(text_bytes[index])):
        index += 1
    return index


def _attribute_name_end(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Int:

    var index = start_index
    while index < end_index:
        var character_code = Int(text_bytes[index])
        if (
            _is_whitespace_byte(character_code)
            or character_code == 47
            or character_code == 62
            or character_code == 61
        ):
            break
        index += 1
    return index


def _unquoted_attribute_value_end(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Int:

    var index = start_index
    while index < end_index:
        var character_code = Int(text_bytes[index])
        if _is_whitespace_byte(character_code) or character_code == 62:
            break
        index += 1
    return index


def _scan_tag(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Tuple[Int, Int, Bool, Bool]:

    var index = _tag_name_end(text_bytes, start_index, end_index)
    var name_end_index = index
    while True:

        index = _skip_tag_whitespace(text_bytes, index, end_index)
        if index >= end_index:
            return (name_end_index, end_index, False, False)
        var character_code = Int(text_bytes[index])
        if character_code == 62:
            return (name_end_index, index + 1, True, False)
        if character_code == 47:

            index += 1
            if index >= end_index:
                return (name_end_index, end_index, False, False)
            if Int(text_bytes[index]) == 62:
                return (name_end_index, index + 1, True, True)
            continue

        index = _attribute_name_end(text_bytes, index, end_index)
        index = _skip_tag_whitespace(text_bytes, index, end_index)
        if index >= end_index:
            return (name_end_index, end_index, False, False)
        if Int(text_bytes[index]) != 61:

            continue

        index += 1
        index = _skip_tag_whitespace(text_bytes, index, end_index)
        if index >= end_index:
            return (name_end_index, end_index, False, False)
        var quote_character = Int(text_bytes[index])
        if quote_character == 34 or quote_character == 39:

            index += 1
            while (
                index < end_index and Int(text_bytes[index]) != quote_character
            ):
                index += 1
            if index >= end_index:
                return (name_end_index, end_index, False, False)
            index += 1
            continue

        index = _unquoted_attribute_value_end(text_bytes, index, end_index)
        if index >= end_index:
            return (name_end_index, end_index, False, False)


def _find_bogus_end(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Int:

    var index = start_index
    while index < end_index:
        if Int(text_bytes[index]) == 62:
            return index + 1
        index += 1
    return end_index


def _find_comment_end(
    text_bytes: BytePtr, start_index: Int, end_index: Int
) -> Int:

    if start_index < end_index and Int(text_bytes[start_index]) == 62:
        return start_index + 1
    if (
        start_index + 1 < end_index
        and Int(text_bytes[start_index]) == 45
        and Int(text_bytes[start_index + 1]) == 62
    ):
        return start_index + 2
    var index = start_index
    while index + 2 < end_index:
        if Int(text_bytes[index]) == 45 and Int(text_bytes[index + 1]) == 45:
            if Int(text_bytes[index + 2]) == 62:
                return index + 3
            if (
                index + 3 < end_index
                and Int(text_bytes[index + 2]) == 33
                and Int(text_bytes[index + 3]) == 62
            ):
                return index + 4
        index += 1
    return end_index


def _find_raw_close(
    text_bytes: BytePtr,
    start_index: Int,
    end_index: Int,
    close_name_bytes: BytePtr,
    close_name_length: Int,
) -> Tuple[Int, Bool]:

    var index = start_index
    while index < end_index:
        if Int(text_bytes[index]) != 60:
            index += 1
            continue
        if index + 1 >= end_index or Int(text_bytes[index + 1]) != 47:
            index += 1
            continue
        var name_scan_index = index + 2
        var name_byte_index = 0
        var mismatch_index = -1
        while name_byte_index < close_name_length:
            if name_scan_index >= end_index:
                return (end_index, False)
            var found_character = Int(text_bytes[name_scan_index])
            var expected_character = Int(close_name_bytes[name_byte_index])
            if (
                found_character != expected_character
                and found_character != expected_character - 32
            ):
                mismatch_index = name_scan_index
                break
            name_scan_index += 1
            name_byte_index += 1
        if mismatch_index >= 0:
            index = mismatch_index
            continue
        if name_scan_index >= end_index:
            return (end_index, False)
        var terminator_character = Int(text_bytes[name_scan_index])
        if (
            terminator_character == 32
            or (terminator_character >= 9 and terminator_character <= 13)
            or terminator_character == 47
            or terminator_character == 62
        ):
            return (index, True)
        index = name_scan_index
    return (end_index, False)


comptime RAW_NONE = 0
comptime RAW_SCRIPT = 1
comptime RAW_STYLE = 2
comptime RAW_TEXTAREA = 3
comptime RAW_TITLE = 4
comptime RAW_PLAINTEXT = 5
comptime RAW_XMP = 6
comptime RAW_IFRAME = 7
comptime RAW_NOEMBED = 8
comptime RAW_NOFRAMES = 9
comptime RAW_NOSCRIPT = 10


def _classify_raw_tag(
    text_bytes: BytePtr, name_start: Int, name_length: Int
) -> Int:

    if _tag_name_equals_literal(text_bytes, name_start, name_length, "script"):
        return RAW_SCRIPT
    if _tag_name_equals_literal(text_bytes, name_start, name_length, "style"):
        return RAW_STYLE
    if _tag_name_equals_literal(
        text_bytes, name_start, name_length, "textarea"
    ):
        return RAW_TEXTAREA
    if _tag_name_equals_literal(text_bytes, name_start, name_length, "title"):
        return RAW_TITLE
    if _tag_name_equals_literal(
        text_bytes, name_start, name_length, "plaintext"
    ):
        return RAW_PLAINTEXT
    if _tag_name_equals_literal(text_bytes, name_start, name_length, "xmp"):
        return RAW_XMP
    if _tag_name_equals_literal(text_bytes, name_start, name_length, "iframe"):
        return RAW_IFRAME
    if _tag_name_equals_literal(text_bytes, name_start, name_length, "noembed"):
        return RAW_NOEMBED
    if _tag_name_equals_literal(
        text_bytes, name_start, name_length, "noframes"
    ):
        return RAW_NOFRAMES
    if _tag_name_equals_literal(
        text_bytes, name_start, name_length, "noscript"
    ):
        return RAW_NOSCRIPT
    return RAW_NONE


def _raw_close_name(raw_kind: Int) -> Tuple[BytePtr, Int]:

    var name_bytes: BytePtr
    var name_length: Int
    if raw_kind == RAW_SCRIPT:
        name_bytes = _literal_byte_pointer("script")
        name_length = 6
    elif raw_kind == RAW_STYLE:
        name_bytes = _literal_byte_pointer("style")
        name_length = 5
    elif raw_kind == RAW_TEXTAREA:
        name_bytes = _literal_byte_pointer("textarea")
        name_length = 8
    elif raw_kind == RAW_TITLE:
        name_bytes = _literal_byte_pointer("title")
        name_length = 5
    elif raw_kind == RAW_XMP:
        name_bytes = _literal_byte_pointer("xmp")
        name_length = 3
    elif raw_kind == RAW_IFRAME:
        name_bytes = _literal_byte_pointer("iframe")
        name_length = 6
    elif raw_kind == RAW_NOEMBED:
        name_bytes = _literal_byte_pointer("noembed")
        name_length = 7
    elif raw_kind == RAW_NOFRAMES:
        name_bytes = _literal_byte_pointer("noframes")
        name_length = 8
    else:
        name_bytes = _literal_byte_pointer("noscript")
        name_length = 8
    return (name_bytes, name_length)


def _drain_end_tag(
    text_bytes: BytePtr,
    name_start: Int,
    name_end: Int,
    last_tag_was_raw: Bool,
    last_tag_name: String,
    skipping: Bool,
    skip_count: Int,
) -> Tuple[String, Bool, Bool, Int]:

    var result_name = last_tag_name
    var result_raw = last_tag_was_raw
    if last_tag_was_raw and last_tag_name == _lowercase_tag_name(
        text_bytes, name_start, name_end
    ):
        result_name = String("")
        result_raw = False
    var result_skipping = skipping
    var result_skip_count = skip_count
    if _tag_name_activates_content_skip(
        text_bytes, name_start, name_end - name_start
    ):
        result_skip_count -= 1
        if result_skip_count == 0:
            result_skipping = False
    return (result_name, result_raw, result_skipping, result_skip_count)


def _codepoint_is_space(codepoint: Int) -> Bool:
    if codepoint < 0x80:
        return (
            codepoint == 0x20
            or codepoint == 0x09
            or codepoint == 0x0A
            or codepoint == 0x0B
            or codepoint == 0x0C
            or codepoint == 0x0D
        )
    if codepoint == 0x85 or codepoint == 0xA0 or codepoint == 0x1680:
        return True
    if codepoint >= 0x2000 and codepoint <= 0x200A:
        return True
    return (
        codepoint == 0x2028
        or codepoint == 0x2029
        or codepoint == 0x202F
        or codepoint == 0x205F
        or codepoint == 0x3000
    )


def _trim_whitespace(byte_pointer: BytePtr, length: Int) -> Tuple[Int, Int]:
    var trimmed_start = 0
    var trimmed_end = length
    while trimmed_start < trimmed_end:
        var decoded_rune = utf8_rune_at(
            byte_pointer, trimmed_start, trimmed_end - trimmed_start
        )
        if decoded_rune[0] < 0 or not _codepoint_is_space(decoded_rune[0]):
            break
        trimmed_start += decoded_rune[1]
    while trimmed_end > trimmed_start:
        var backward_end = trimmed_end
        var probe_start = backward_end - 4
        if probe_start < trimmed_start:
            probe_start = trimmed_start
        var probe_index = probe_start
        var found_codepoint = -1
        var rune_width = 1
        while probe_index < backward_end:
            var decoded_rune = utf8_rune_at(
                byte_pointer, probe_index, backward_end - probe_index
            )
            if (
                decoded_rune[0] >= 0
                and probe_index + decoded_rune[1] == backward_end
            ):
                found_codepoint = decoded_rune[0]
                rune_width = decoded_rune[1]
                break
            probe_index += 1
        if found_codepoint < 0:
            found_codepoint = Int(byte_pointer[backward_end - 1])
            rune_width = 1
        if not _codepoint_is_space(found_codepoint):
            break
        trimmed_end -= rune_width
    return (trimmed_start, trimmed_end)


def strip_html_to_text(html_text: String) -> String:

    var byte_length = html_text.byte_length()
    if byte_length == 0:
        return String("")
    var source_bytes = html_text.as_bytes()
    var source_pointer = BytePtr(
        unsafe_from_address=Int(source_bytes.unsafe_ptr())
    )
    var output_buffer = ByteBuf(byte_length * 2 + 64)

    var index = 0
    var skipping = False
    var skip_count = 0
    var last_start_tag_name = String("")
    var last_start_tag_was_raw = False

    while index < byte_length:

        if Int(source_pointer[index]) != 60:
            var text_end_index = index
            while (
                text_end_index < byte_length
                and Int(source_pointer[text_end_index]) != 60
            ):
                text_end_index += 1
            if not skipping:
                _convert_text_bytes_to_plain_text(
                    source_pointer, index, text_end_index, True, output_buffer
                )
            index = text_end_index
            continue

        if index + 1 >= byte_length:
            if not skipping:
                _push_escaped_byte(output_buffer, 60)
            index += 1
            continue

        var character_after_open = Int(source_pointer[index + 1])

        if character_after_open == 47:
            if index + 2 >= byte_length:

                if not skipping:
                    _push_escaped_byte(output_buffer, 60)
                    _push_escaped_byte(output_buffer, 47)
                index += 2
                continue
            var character_after_solidus = Int(source_pointer[index + 2])
            if _is_ascii_letter(character_after_solidus):
                var end_tag_result = _scan_tag(
                    source_pointer, index + 2, byte_length
                )
                if not end_tag_result[2]:
                    index = byte_length
                    continue

                var drain_result = _drain_end_tag(
                    source_pointer,
                    index + 2,
                    end_tag_result[0],
                    last_start_tag_was_raw,
                    last_start_tag_name,
                    skipping,
                    skip_count,
                )
                last_start_tag_name = drain_result[0]
                last_start_tag_was_raw = drain_result[1]
                skipping = drain_result[2]
                skip_count = drain_result[3]
                index = end_tag_result[1]
                continue
            if character_after_solidus == 62:

                index += 3
                continue

            index = _find_bogus_end(source_pointer, index + 2, byte_length)
            continue

        if character_after_open == 33:
            if (
                index + 3 < byte_length
                and Int(source_pointer[index + 2]) == 45
                and Int(source_pointer[index + 3]) == 45
            ):

                index = _find_comment_end(
                    source_pointer, index + 4, byte_length
                )
                continue
            if _range_equals_literal_case_insensitive(
                source_pointer, index + 2, 7, "doctype"
            ):

                index = _find_bogus_end(source_pointer, index + 9, byte_length)
                continue

            index = _find_bogus_end(source_pointer, index + 2, byte_length)
            continue

        if character_after_open == 63:
            index = _find_bogus_end(source_pointer, index + 2, byte_length)
            continue

        if _is_ascii_letter(character_after_open):
            var start_tag_result = _scan_tag(
                source_pointer, index + 1, byte_length
            )
            if not start_tag_result[2]:

                index = byte_length
                continue
            var name_start = index + 1
            var name_length = start_tag_result[0] - name_start
            var raw_kind = _classify_raw_tag(
                source_pointer, name_start, name_length
            )
            index = start_tag_result[1]

            if not start_tag_result[3]:
                last_start_tag_name = _lowercase_tag_name(
                    source_pointer, name_start, start_tag_result[0]
                )
                last_start_tag_was_raw = (
                    raw_kind == RAW_SCRIPT or raw_kind == RAW_STYLE
                )
                if (
                    not last_start_tag_was_raw
                    and _tag_name_activates_content_skip(
                        source_pointer, name_start, name_length
                    )
                ):
                    skipping = True
                    skip_count += 1

            if raw_kind != RAW_NONE:
                if raw_kind == RAW_PLAINTEXT:

                    if not skipping:
                        _convert_text_bytes_to_plain_text(
                            source_pointer,
                            index,
                            byte_length,
                            False,
                            output_buffer,
                        )
                    index = byte_length
                    continue
                var close_name_pair = _raw_close_name(raw_kind)
                var close_result = _find_raw_close(
                    source_pointer,
                    index,
                    byte_length,
                    close_name_pair[0],
                    close_name_pair[1],
                )

                if raw_kind == RAW_TEXTAREA and not skipping:
                    _convert_text_bytes_to_plain_text(
                        source_pointer,
                        index,
                        close_result[0],
                        True,
                        output_buffer,
                    )
                elif raw_kind == RAW_XMP and not skipping:
                    _convert_text_bytes_to_plain_text(
                        source_pointer,
                        index,
                        close_result[0],
                        False,
                        output_buffer,
                    )
                if close_result[1]:
                    var close_tag_result = _scan_tag(
                        source_pointer, close_result[0] + 2, byte_length
                    )
                    if not close_tag_result[2]:
                        index = byte_length
                        continue
                    var drain_result = _drain_end_tag(
                        source_pointer,
                        close_result[0] + 2,
                        close_tag_result[0],
                        last_start_tag_was_raw,
                        last_start_tag_name,
                        skipping,
                        skip_count,
                    )
                    last_start_tag_name = drain_result[0]
                    last_start_tag_was_raw = drain_result[1]
                    skipping = drain_result[2]
                    skip_count = drain_result[3]
                    index = close_tag_result[1]
                else:

                    index = byte_length
            continue

        if not skipping:
            _push_escaped_byte(output_buffer, 60)
        index += 1

    var result_pointer = retracked(output_buffer.ptr)
    var result_length = output_buffer.size
    var trimmed_range = _trim_whitespace(result_pointer, result_length)
    var result = String(
        unsafe_from_utf8=Span(
            unsafe_ptr=result_pointer + trimmed_range[0],
            length=trimmed_range[1] - trimmed_range[0],
        )
    )
    free_bytes(result_pointer)
    return result
