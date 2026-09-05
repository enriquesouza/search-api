"""mojosearch.entities.price — the money wire wrapper.

origin: alugue-mojo-api models/price.mojo
"""

from mojoserde import ByteBuf, WireValue, write_f64_compact


@fieldwise_init
struct Price(Copyable, Defaultable, Movable, WireValue):

    var amount: Float64

    def __init__(out self):
        self.amount = 0.0

    def write_wire(self, mut buffer: ByteBuf):
        write_f64_compact(buffer, self.amount)
