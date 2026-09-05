"""mojosearch.web.market_code — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby/_market_code.mojo
"""

from mojoflask import BytePtr

from mojosearch.web.numeric_core import ASC_CASE_DELTA


comptime CH_SPACE = 32
comptime ASC_UPPER_LO = 65
comptime ASC_UPPER_HI = 90
comptime CH_QUESTION = 63
comptime CH_SLASH = 47


def market_code_from_request_head(
    request_head: BytePtr, head_length: Int
) -> StaticString:

    var scan_index = 0
    while (
        scan_index < head_length and Int(request_head[scan_index]) != CH_SPACE
    ):
        scan_index += 1
    if scan_index >= head_length or Int(request_head[scan_index]) != CH_SPACE:
        return "other"
    if (
        scan_index + 1 >= head_length
        or Int(request_head[scan_index + 1]) != CH_SLASH
    ):
        return "other"
    var start = scan_index + 2
    var end = start
    while end < head_length:
        var character_value = Int(request_head[end])
        if (
            character_value == CH_SLASH
            or character_value == CH_SPACE
            or character_value == CH_QUESTION
        ):
            break
        end += 1
    if end - start != 2:
        return "other"

    var first_character = Int(request_head[start])
    var second_character = Int(request_head[start + 1])
    if first_character >= ASC_UPPER_LO and first_character <= ASC_UPPER_HI:
        first_character += ASC_CASE_DELTA
    if second_character >= ASC_UPPER_LO and second_character <= ASC_UPPER_HI:
        second_character += ASC_CASE_DELTA

    if first_character == 98 and second_character == 114:
        return "br"
    if first_character == 97 and second_character == 114:
        return "ar"
    if first_character == 109 and second_character == 120:
        return "mx"
    if first_character == 99 and second_character == 111:
        return "co"
    if first_character == 99 and second_character == 108:
        return "cl"
    if first_character == 112 and second_character == 101:
        return "pe"
    if first_character == 117 and second_character == 115:
        return "us"
    if first_character == 101 and second_character == 115:
        return "es"
    return "other"
