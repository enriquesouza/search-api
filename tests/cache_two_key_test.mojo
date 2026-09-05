from mojoka import (
    KeyBuilder,
    SlotTable,
    StoredBytes,
    fnv_byte,
    fnv_init,
    malloc_bytes,
)

from mojosearch.cache import CACHE_CAPACITY, NearbyResponseCache
from mojosearch.cache_keys import (
    MAX_RESULTS,
    append_cache_key_from_request,
    cache_grid_cell_for_coordinates,
)

from mojosearch.services.nearby_request import NearbyRequest


comptime IDENTITY_HASH_V1 = UInt64(0x8A944B53A45237E2)
comptime IDENTITY_HASH_V1_QUERY = UInt64(0xCC33922037B46EC9)
comptime BR_HASH_V1_QUERY = UInt64(0xB01003BEA79820F5)
comptime BR_HASH_V1_PLAIN = UInt64(0xCC339B2037B47E14)
comptime IDENTITY_HASH_V2 = UInt64(0xAB611959B3332245)


def make_cache(mmap_values: Bool) -> NearbyResponseCache:
    return NearbyResponseCache(
        slots=SlotTable(CACHE_CAPACITY, 3_600_000_000_000),
        key_builder=KeyBuilder(),
        identity_length=0,
        mmap_values=mmap_values,
    )


def make_request() -> NearbyRequest:
    var request = NearbyRequest()
    request.limit = 12
    request.skip = 0
    request.lat = -23.5505
    request.lng = -46.6333
    request.has_geo = True
    request.filters = List[Int32]()
    request.filters.append(7)
    request.filters.append(42)
    request.periods = List[UInt8]()
    request.periods.append(1)
    request.periods.append(2)
    request.periods.append(3)
    return request^


def key_bytes_match(imm cache: NearbyResponseCache, expected: StaticString) -> Bool:
    var key_bytes = expected.as_bytes()
    if cache.key_builder.len != len(key_bytes):
        return False
    var builder_bytes = cache.key_builder.buf
    var byte_index = 0
    while byte_index < len(key_bytes):
        if Int(builder_bytes[unsafe_offset=byte_index]) != Int(
            key_bytes[byte_index]
        ):
            return False
        byte_index += 1
    return True


def stored_bytes_equal(
    stored: StoredBytes, expected: StaticString
) -> Bool:
    var expected_bytes = expected.as_bytes()
    if stored.len != len(expected_bytes):
        return False
    var byte_index = 0
    while byte_index < len(expected_bytes):
        if Int(stored.data[unsafe_offset=byte_index]) != Int(
            expected_bytes[byte_index]
        ):
            return False
        byte_index += 1
    return True


def fail(message: StaticString) raises:
    raise Error("SELFTEST FAIL: " + message)


def main() raises:
    print("[1] grid cell rounding law")
    var grid = cache_grid_cell_for_coordinates(-23.5505, -46.6333, True)
    if grid[0] != -23.551 or grid[1] != -46.633:
        fail("grid3 rounding of the sao paulo pair drifted")
    var origin_grid = cache_grid_cell_for_coordinates(0.0004, 0.0002, True)
    if origin_grid[0] != 0.0004 or origin_grid[1] != 0.0002:
        fail("origin grid cell must keep the RAW coordinates")
    var no_geo_grid = cache_grid_cell_for_coordinates(0.0004, 0.0002, False)
    if no_geo_grid[0] != 0.0 or no_geo_grid[1] != 0.0:
        fail("absent coordinates must snap to the (0,0) grid cell")

    print("[2] frozen key layout bytes + FNV vectors (query marker)")
    var cache = make_cache(mmap_values=False)
    var request = make_request()
    var keyed_grid = cache_grid_cell_for_coordinates(
        request.lat, request.lng, request.has_geo
    )
    append_cache_key_from_request(
        cache.key_builder, "mojo", request, keyed_grid[0], keyed_grid[1]
    )
    if not key_bytes_match(
        cache, "mojo|12|0|-23.551|-46.633|7|42|\x01|\x02|\x03"
    ):
        fail("identity key layout drifted from the frozen byte contract")
    var identity_hash = cache.mark_identity_key(query_marker=True)
    if identity_hash != IDENTITY_HASH_V1_QUERY:
        fail("query-marked identity FNV vector drifted")
    if not key_bytes_match(
        cache, "mojo|12|0|-23.551|-46.633|7|42|\x01|\x02|\x03q"
    ):
        fail("query marker was not appended as the final key byte")
    var br_hash = cache.extend_br_key()
    if br_hash != BR_HASH_V1_QUERY:
        fail("br FNV vector drifted (one '~' past the identity key)")
    if br_hash == identity_hash:
        fail("the two-key law collapsed: br hash equals identity hash")

    print("[3] FNV vectors (no query marker)")
    var plain_cache = make_cache(mmap_values=False)
    append_cache_key_from_request(
        plain_cache.key_builder, "mojo", request, keyed_grid[0], keyed_grid[1]
    )
    var plain_identity = plain_cache.mark_identity_key(query_marker=False)
    if plain_identity != IDENTITY_HASH_V1:
        fail("unmarked identity FNV vector drifted")
    var plain_br = plain_cache.extend_br_key()
    if plain_br != BR_HASH_V1_PLAIN:
        fail("br-over-plain-key FNV vector drifted")
    if plain_cache.key_builder.len != plain_cache.identity_length + 1:
        fail("the br marker must sit exactly one byte past identity_length")

    print("[4] skip sentinel clamp at MAX_RESULTS")
    var clamped_request = make_request()
    clamped_request.limit = 50
    clamped_request.skip = MAX_RESULTS * 5
    clamped_request.lat = 0.0
    clamped_request.lng = 0.0
    clamped_request.has_geo = False
    clamped_request.filters = List[Int32]()
    clamped_request.periods = List[UInt8]()
    var clamped_cache = make_cache(mmap_values=False)
    append_cache_key_from_request(
        clamped_cache.key_builder, "alugue", clamped_request, 0.0, 0.0
    )
    if not key_bytes_match(clamped_cache, "alugue|50|200|0.000|0.000"):
        fail("skip sentinel clamp or the zero grid spelling drifted")
    var clamped_identity = clamped_cache.mark_identity_key(query_marker=False)
    if clamped_identity != IDENTITY_HASH_V2:
        fail("clamped-skip FNV vector drifted")

    print("[5] two-key set/get roundtrip with read-back law")
    comptime identity_payload = "HTTP/1.1 200 OK\r\n\r\n{\"result\":[]}"
    comptime br_payload = "\x1b\x2d\x28brob"
    var identity_bytes = identity_payload.as_bytes()
    var owned_identity = malloc_bytes(len(identity_bytes))
    var fill_index = 0
    while fill_index < len(identity_bytes):
        owned_identity[unsafe_offset=fill_index] = identity_bytes[fill_index]
        fill_index += 1
    var stored_identity = cache.set_identity(
        identity_hash, owned_identity, len(identity_bytes)
    )
    if not stored_bytes_equal(stored_identity, identity_payload):
        fail("set_identity read-back drifted from the stored bytes")
    var probed_identity = cache.get_identity(identity_hash)
    if not stored_bytes_equal(probed_identity, identity_payload):
        fail("get_identity missed right after set_identity")
    if cache.get_br(br_hash).len != 0:
        fail("br key hit before set_br: the two keys are not independent")
    var br_bytes = br_payload.as_bytes()
    var owned_br = malloc_bytes(len(br_bytes))
    fill_index = 0
    while fill_index < len(br_bytes):
        owned_br[unsafe_offset=fill_index] = br_bytes[fill_index]
        fill_index += 1
    var stored_br = cache.set_br(br_hash, owned_br, len(br_bytes))
    if not stored_bytes_equal(stored_br, br_payload):
        fail("set_br read-back drifted from the stored bytes")
    if not stored_bytes_equal(cache.get_identity(identity_hash), identity_payload):
        fail("set_br clobbered the identity slot")
    if not stored_bytes_equal(cache.get_br(br_hash), br_payload):
        fail("get_br missed right after set_br")

    print("[6] miss law on a cold cache")
    var cold_cache = make_cache(mmap_values=False)
    append_cache_key_from_request(
        cold_cache.key_builder, "mojo", request, keyed_grid[0], keyed_grid[1]
    )
    var cold_identity = cold_cache.mark_identity_key(query_marker=True)
    if cold_cache.get_identity(cold_identity).len != 0:
        fail("cold cache served an identity hit")

    print("[7] mmap value law")
    var mmap_cache = make_cache(mmap_values=True)
    append_cache_key_from_request(
        mmap_cache.key_builder, "mojo", request, keyed_grid[0], keyed_grid[1]
    )
    var mmap_identity = mmap_cache.mark_identity_key(query_marker=True)
    var owned_mmap_payload = malloc_bytes(len(identity_bytes))
    fill_index = 0
    while fill_index < len(identity_bytes):
        owned_mmap_payload[unsafe_offset=fill_index] = identity_bytes[fill_index]
        fill_index += 1
    var mmap_stored = mmap_cache.set_identity(
        mmap_identity, owned_mmap_payload, len(identity_bytes)
    )
    if not stored_bytes_equal(mmap_stored, identity_payload):
        fail("mmap-backed set_identity read-back drifted")
    if not mmap_stored.mapped:
        fail("mmap_values=True must store the mapped copy")
    if not stored_bytes_equal(
        mmap_cache.get_identity(mmap_identity), identity_payload
    ):
        fail("mmap-backed get_identity missed")

    print("[8] mojoka primitive agreement (one-shot FNV over the key bytes)")
    var vector_bytes = "mojo|12|0|-23.551|-46.633|7|42|\x01|\x02|\x03q".as_bytes()
    var vector_ptr = malloc_bytes(len(vector_bytes))
    fill_index = 0
    while fill_index < len(vector_bytes):
        vector_ptr[unsafe_offset=fill_index] = vector_bytes[fill_index]
        fill_index += 1
    var one_shot_hash = fnv_byte(fnv_init(), vector_ptr, len(vector_bytes))
    if identity_hash != one_shot_hash:
        fail("mark_identity_key disagrees with the raw mojoka FNV primitives")

    print("cache_two_key_test: ALL PASS")
