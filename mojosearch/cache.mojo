from mojoflask import BytePtr
from mojoka import (
    KeyBuilder,
    SlotTable,
    StoredBytes,
    free_bytes,
    key_hash,
    map_alloc,
    retracked,
    stored_mapped,
    stored_owned,
)


comptime CACHE_CAPACITY = 4096


comptime QUERY_KEY_MARKER = UInt8(113)
comptime BR_KEY_MARKER = UInt8(126)


def _copy_mmap_region(source: BytePtr, length: Int) -> BytePtr:

    var mapped_copy = map_alloc(length)
    var byte_index = 0
    while byte_index < length:
        mapped_copy[byte_index] = source[byte_index]
        byte_index += 1
    return mapped_copy


@fieldwise_init
struct NearbyResponseCache(Movable):

    var slots: SlotTable
    var key_builder: KeyBuilder
    var identity_length: Int
    var mmap_values: Bool

    def mark_identity_key(mut self, query_marker: Bool) -> UInt64:

        if query_marker:
            self.key_builder.buf[
                unsafe_offset=self.key_builder.len
            ] = QUERY_KEY_MARKER
            self.key_builder.len += 1
        self.identity_length = self.key_builder.len
        return key_hash(self.key_builder)

    def extend_br_key(mut self) -> UInt64:

        self.key_builder.buf[unsafe_offset=self.key_builder.len] = BR_KEY_MARKER
        self.key_builder.len += 1
        return key_hash(self.key_builder)

    def get_identity(self, base_hash: UInt64) -> StoredBytes:

        return self.slots.get(
            base_hash, retracked(self.key_builder.buf), self.identity_length
        )

    def get_br(self, br_hash: UInt64) -> StoredBytes:

        return self.slots.get(
            br_hash, retracked(self.key_builder.buf), self.key_builder.len
        )

    def set_identity(
        mut self, base_hash: UInt64, data: BytePtr, length: Int
    ) -> StoredBytes:

        if self.mmap_values:
            var mapped_copy = _copy_mmap_region(data, length)
            free_bytes(data)
            self.slots.set(
                base_hash,
                retracked(self.key_builder.buf),
                self.identity_length,
                stored_mapped(mapped_copy, length),
            )
            return self.slots.get(
                base_hash, retracked(self.key_builder.buf), self.identity_length
            )
        self.slots.set(
            base_hash,
            retracked(self.key_builder.buf),
            self.identity_length,
            stored_owned(data, length),
        )
        return self.slots.get(
            base_hash, retracked(self.key_builder.buf), self.identity_length
        )

    def set_br(
        mut self, br_hash: UInt64, data: BytePtr, length: Int
    ) -> StoredBytes:

        if self.mmap_values:
            var mapped_copy = _copy_mmap_region(data, length)
            free_bytes(data)
            self.slots.set(
                br_hash,
                retracked(self.key_builder.buf),
                self.key_builder.len,
                stored_mapped(mapped_copy, length),
            )
        else:
            self.slots.set(
                br_hash,
                retracked(self.key_builder.buf),
                self.key_builder.len,
                stored_owned(data, length),
            )
        return self.slots.get(
            br_hash, retracked(self.key_builder.buf), self.key_builder.len
        )
