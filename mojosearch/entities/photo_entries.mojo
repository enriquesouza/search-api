"""mojosearch.entities.photo_entries — the gallery wire value.

origin: alugue-mojo-api models/photo_entries.mojo
"""

from mojoserde.buf import ByteBuf
from mojoserde.gostring import write_go_string
from mojoserde.indexed_entries import (
    stripped_indexed_entries_in_stable_ordinal_order,
    stripped_indexed_entry,
)
from mojoserde.wire import WireValue


def decode_photo_entry(entry: String) -> String:
    return stripped_indexed_entry(entry)


@fieldwise_init
struct PhotoEntries(Copyable, Defaultable, Movable, WireValue):
    var items: List[String]

    def __init__(out self):
        self.items = List[String]()

    def write_wire(self, mut buffer: ByteBuf):
        buffer.push_ascii(91)
        var photos = stripped_indexed_entries_in_stable_ordinal_order(
            self.items
        )
        var photo_index = 0
        while photo_index < len(photos):
            if photo_index > 0:
                buffer.push_ascii(44)
            write_go_string(buffer, photos[photo_index])
            photo_index += 1
        buffer.push_ascii(93)


def photo_entries_from_list(imm source_entries: List[String]) -> PhotoEntries:
    return PhotoEntries(items=List[String](source_entries))


def optional_photo_entries_from_optional_list(
    imm source_entries: Optional[List[String]],
) -> Optional[PhotoEntries]:
    var optional_photo_entries = Optional[PhotoEntries]()
    if source_entries:
        optional_photo_entries = Optional[PhotoEntries](
            photo_entries_from_list(source_entries.value())
        )
    return optional_photo_entries^
