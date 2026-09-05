struct NearbyRequest(Copyable, Movable):

    var limit: Int
    var skip: Int
    var lat: Float64
    var lng: Float64
    var has_geo: Bool
    var filters: List[Int32]
    var periods: List[UInt8]

    def __init__(out self):
        self.limit = 12
        self.skip = 0
        self.lat = 0
        self.lng = 0
        self.has_geo = False
        self.filters = List[Int32]()
        self.periods = List[UInt8]()
