"""mojosearch.entities.listing — the nearby/recommended listing wire entity.

origin: alugue-mojo-api models/listing.mojo
"""

from mojoflask import BytePtr

from pqmojo import FromRow, RowColumns

from mojosearch.entities.photo_entries import PhotoEntries, photo_entries_from_list
from mojosearch.entities.price import Price
from mojoserde import (
    Arr,
    AlwaysNull,
    TimestampMicros,
    WireSkips,
    WireSkipSet,
)

from mojosearch.web.numeric_core import (
    parse_postgres_timestamp_nearby_bytes,
)


comptime MILES_PER_METRE = 1.0 / 1609.344


struct NearbyListingRow(Copyable, Defaultable, FromRow, Movable):

    var id: Int64
    var advertiser_id: Int64
    var latitude: Float64
    var longitude: Float64
    var title: String
    var street: String
    var house_number: Optional[Int32]
    var complement: String
    var period: String
    var daily_price: Float64
    var weekly_price: Float64
    var monthly_price: Float64
    var yearly_price: Float64
    var hourly_price: Float64
    var period_price: Float64
    var data_anuncio: String
    var filters: List[Int32]
    var photos: List[String]
    var review_rate: Int32
    var quality_score: Optional[Int32]
    var distance: Float64

    def __init__(out self):
        self.id = 0
        self.advertiser_id = 0
        self.latitude = 0
        self.longitude = 0
        self.title = String("")
        self.street = String("")
        self.house_number = Optional[Int32]()
        self.complement = String("")
        self.period = String("")
        self.daily_price = 0
        self.weekly_price = 0
        self.monthly_price = 0
        self.yearly_price = 0
        self.hourly_price = 0
        self.period_price = 0
        self.data_anuncio = String("")
        self.filters = List[Int32]()
        self.photos = List[String]()
        self.review_rate = 0
        self.quality_score = Optional[Int32]()
        self.distance = 0

    @staticmethod
    def row_columns() raises -> RowColumns:
        var column_list = RowColumns()
        column_list.add("id")
        column_list.add("advertiser_id")
        column_list.add("latitude")
        column_list.add("longitude")
        column_list.add("title")
        column_list.add("street")
        column_list.add("house_number")
        column_list.add("complement")
        column_list.add("period")
        column_list.add("daily_price")
        column_list.add("weekly_price")
        column_list.add("monthly_price")
        column_list.add("yearly_price")
        column_list.add("hourly_price")
        column_list.add("period_price")
        column_list.add("data_anuncio")
        column_list.add("filters_array")
        column_list.add("photos_array")
        column_list.add("review_rate")
        column_list.add("quality_score")
        column_list.add("distance")
        return column_list^


@fieldwise_init
struct ListingJson(Copyable, Movable, WireSkips):

    var id: Int64
    var advertiser_id: Int64
    var latitude: Float64
    var longitude: Float64
    var title: String
    var description: String
    var street: String
    var house_number: Optional[Int32]
    var complement: String
    var contact_phone: String
    var neighborhood: String
    var city: String
    var state: String
    var zip_code: String
    var period: String
    var daily_price: Price
    var weekly_price: Price
    var monthly_price: Price
    var yearly_price: Price
    var hourly_price: Price
    var period_price: Price
    var created_at: TimestampMicros
    var miles: Price
    var filters: Arr[Int32]
    var photos: PhotoEntries
    var review_rate: Int32
    var quality_score: Optional[Int32]
    var median_rating: AlwaysNull
    var is_favorite: Int32
    var count_total: Int32

    @staticmethod
    def wire_skips() -> WireSkipSet:
        var skip_set = WireSkipSet()
        skip_set.add("neighborhood")
        skip_set.add("city")
        skip_set.add("state")
        skip_set.add("zip_code")
        skip_set.add("quality_score")
        return skip_set^


def listing_json_from_nearby_row(
    imm row: NearbyListingRow, has_geo: Bool
) -> ListingJson:

    var data_anuncio_bytes = row.data_anuncio.as_bytes()
    var data_anuncio_byte_pointer = BytePtr(
        unsafe_from_address=Int(data_anuncio_bytes.unsafe_ptr())
    )
    var distance_in_miles: Float64 = -1.0
    if has_geo:
        distance_in_miles = row.distance * MILES_PER_METRE
    return ListingJson(
        id=row.id,
        advertiser_id=row.advertiser_id,
        latitude=row.latitude,
        longitude=row.longitude,
        title=row.title,
        description=String(""),
        street=row.street,
        house_number=row.house_number,
        complement=row.complement,
        contact_phone=String(""),
        neighborhood=String(""),
        city=String(""),
        state=String(""),
        zip_code=String(""),
        period=row.period,
        daily_price=Price(row.daily_price),
        weekly_price=Price(row.weekly_price),
        monthly_price=Price(row.monthly_price),
        yearly_price=Price(row.yearly_price),
        hourly_price=Price(row.hourly_price),
        period_price=Price(row.period_price),
        created_at=TimestampMicros(
            parse_postgres_timestamp_nearby_bytes(
                data_anuncio_byte_pointer, len(data_anuncio_bytes)
            )
        ),
        miles=Price(distance_in_miles),
        filters=Arr[Int32](items=List[Int32](row.filters)),
        photos=photo_entries_from_list(row.photos),
        review_rate=row.review_rate,
        quality_score=row.quality_score,
        median_rating=AlwaysNull(),
        is_favorite=0,
        count_total=0,
    )
