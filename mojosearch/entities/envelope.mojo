"""Mojosearch entities envelope — the generic response wrapper carrier and
the canonical error body, moved verbatim from the application, wire bytes
frozen.

origin: alugue-mojo-api models/envelope.mojo
"""

from mojoserde import AlwaysNull


comptime ERROR_BODY = '{"error_message":"An error occurred.","result":null,"has_more":false,"count_total":0,"save_changes_result":0,"type":""}'


@fieldwise_init
struct OkResponseWrapperJson[R: Deinitable & Copyable](Copyable, Movable):

    var error_message: AlwaysNull
    var result: Self.R
    var has_more: Bool
    var count_total: Int64
    var save_changes_result: Int32
    var type: String
