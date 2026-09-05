from mojoflask import BytePtr

from mojoka import KeyBuilder, round3_half_away

from mojosearch.services.nearby_request import NearbyRequest


comptime MAX_RESULTS = 200


comptime KEY_SEPARATOR_PIPE = 124


def cache_grid_cell_for_coordinates(
    latitude: Float64, longitude: Float64, coordinates_present: Bool
) -> Tuple[Float64, Float64]:

    var rounded_latitude = round3_half_away(latitude)
    var rounded_longitude = round3_half_away(longitude)
    if (
        coordinates_present
        and rounded_latitude == 0.0
        and rounded_longitude == 0.0
    ):
        return (latitude, longitude)
    return (rounded_latitude, rounded_longitude)


def _append_byte_to_key_builder(mut key_builder: KeyBuilder, byte_value: UInt8):

    var single_byte: Byte = Byte(byte_value)
    key_builder.append_bytes(
        BytePtr(unsafe_from_address=Int(Pointer(to=single_byte))), 1
    )


def _append_key_separator(mut key_builder: KeyBuilder):

    _append_byte_to_key_builder(key_builder, UInt8(KEY_SEPARATOR_PIPE))


def append_cache_key_from_request(
    mut key_builder: KeyBuilder,
    market: StaticString,
    request: NearbyRequest,
    grid_latitude: Float64,
    grid_longitude: Float64,
):

    key_builder.reset()
    key_builder.append_str(String(market))
    _append_key_separator(key_builder)
    key_builder.append_int(request.limit)
    _append_key_separator(key_builder)
    var sentinel = request.skip
    if sentinel > MAX_RESULTS:
        sentinel = MAX_RESULTS
    key_builder.append_int(sentinel)
    _append_key_separator(key_builder)
    key_builder.append_grid3(grid_latitude)
    _append_key_separator(key_builder)
    key_builder.append_grid3(grid_longitude)
    for filter_index in range(len(request.filters)):
        _append_key_separator(key_builder)
        key_builder.append_int(Int(request.filters[filter_index]))
    for period_index in range(len(request.periods)):
        _append_key_separator(key_builder)
        _append_byte_to_key_builder(key_builder, request.periods[period_index])
