from pqmojo import RowPlan


struct SearchRowPlan(Copyable, Movable):

    var plan: RowPlan
    var resolved: Bool

    def __init__(out self):
        self.plan = RowPlan()
        self.resolved = False


comptime POOL_MODULE_NEARBY = 2
comptime POOL_MODULE_DETAILS = 4
