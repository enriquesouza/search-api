"""Mojosearch entities listing_details — the details row, the wire details
entity and its row conversion, moved verbatim from the application, wire
bytes frozen.

origin: alugue-mojo-api models/listing_details.mojo
"""

from mojoflask import BytePtr

from mojosearch.entities.html_to_text import strip_html_to_text

from pqmojo import (
    FromRow,
    PgResult,
    PgSymbols,
    RowColumns,
    RowValue,
    split_postgres_int64_array,
)

from mojosearch.entities.photo_entries import PhotoEntries
from mojosearch.entities.price import Price
from mojoserde import (
    Arr,
    AlwaysNull,
    RawJson,
    TimestampMicros,
    WireSkips,
    WireSkipSet,
    optional_non_empty_raw_json,
    optional_when,
)

from pqmojo.timestamp import parse_postgres_timestamp_bytes_lenient

from mojosearch.entities.photo_entries import (
    PhotoEntries,
    photo_entries_from_list,
)


struct ChildrenIds(Copyable, Movable, RowValue):

    var ids: List[Int64]

    def __init__(out self):
        self.ids = List[Int64]()

    def __init__(out self, var ids: List[Int64]):
        self.ids = ids^

    @staticmethod
    def read_text_cell(
        result: PgResult, row: Int, column_index: Int, out row_value: Self
    ) raises:
        row_value = ChildrenIds(
            split_postgres_int64_array(result.col_text(row, column_index))
        )

    @staticmethod
    def read_binary_cell(
        result: PgResult,
        row: Int,
        column_index: Int,
        symbols: PgSymbols,
        out row_value: Self,
    ) raises:
        row_value = ChildrenIds(
            split_postgres_int64_array(result.bin_text(row, column_index))
        )


struct ListingDetailsRow(Copyable, Defaultable, FromRow, Movable):

    var id: Int64
    var advertiser_id: Int64
    var latitude: Float64
    var longitude: Float64
    var title: String
    var description: String
    var house_number: Optional[Int32]
    var neighborhood: String
    var city: String
    var state: String
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
    var source_url: Optional[String]
    var source: Optional[String]
    var quality_score: Optional[Int32]
    var prices_jsonb: String
    var availability_jsonb: String
    var owner_managed: Bool
    var llm_title: Optional[String]
    var llm_description: Optional[String]
    var parent_listing_id: Optional[Int64]
    var children: Optional[ChildrenIds]
    var is_catalog: Bool
    var duplicate_of: Optional[Int64]
    var source_offers_jsonb: String

    def __init__(out self):
        self.id = 0
        self.advertiser_id = 0
        self.latitude = 0
        self.longitude = 0
        self.title = String("")
        self.description = String("")
        self.house_number = Optional[Int32]()
        self.neighborhood = String("")
        self.city = String("")
        self.state = String("")
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
        self.source_url = Optional[String]()
        self.source = Optional[String]()
        self.quality_score = Optional[Int32]()
        self.prices_jsonb = String("")
        self.availability_jsonb = String("")
        self.owner_managed = False
        self.llm_title = Optional[String]()
        self.llm_description = Optional[String]()
        self.parent_listing_id = Optional[Int64]()
        self.children = Optional[ChildrenIds]()
        self.is_catalog = False
        self.duplicate_of = Optional[Int64]()
        self.source_offers_jsonb = String("")

    @staticmethod
    def row_columns() raises -> RowColumns:
        var column_list = RowColumns()
        column_list.add("id")
        column_list.add("advertiser_id")
        column_list.add("latitude")
        column_list.add("longitude")
        column_list.add("title")
        column_list.add("description")
        column_list.add("house_number")
        column_list.add("neighborhood")
        column_list.add("city")
        column_list.add("state")
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
        column_list.add("source_url")
        column_list.add("source")
        column_list.add("quality_score")
        column_list.add("prices_jsonb")
        column_list.add("availability_jsonb")
        column_list.add("owner_managed")
        column_list.add("llm_title")
        column_list.add("llm_description")
        column_list.add("parent_listing_id")
        column_list.add("children_array")
        column_list.add("is_catalog")
        column_list.add("duplicate_of")
        column_list.add("source_offers_jsonb")
        return column_list^


@fieldwise_init
struct DetailsJson(Copyable, Movable, WireSkips):

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
    var prices_jsonb: Optional[RawJson]
    var availability_jsonb: Optional[RawJson]
    var owner_managed: Optional[Bool]
    var llm_title: String
    var llm_description: String
    var parent_listing_id: Optional[Int64]
    var children_array: Optional[Arr[Int64]]
    var is_catalog: Optional[Bool]
    var duplicate_of: Optional[Int64]
    var source_offers_jsonb: Optional[RawJson]
    var created_at: TimestampMicros
    var miles: Price
    var filters: Arr[Int32]
    var photos: PhotoEntries
    var review_rate: Int32
    var source_url: String
    var quality_score: Optional[Int32]
    var source: String
    var client_info: AlwaysNull
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
        skip_set.add("prices_jsonb")
        skip_set.add("availability_jsonb")
        skip_set.add("owner_managed")
        skip_set.add("llm_title")
        skip_set.add("llm_description")
        skip_set.add("parent_listing_id")
        skip_set.add("children_array")
        skip_set.add("is_catalog")
        skip_set.add("duplicate_of")
        skip_set.add("source_offers_jsonb")
        skip_set.add("source_url")
        skip_set.add("quality_score")
        skip_set.add("source")
        return skip_set^


def details_out_of(imm row: ListingDetailsRow) -> DetailsJson:

    var created_at_bytes = row.data_anuncio.as_bytes()
    var created_at_pointer = BytePtr(
        unsafe_from_address=Int(created_at_bytes.unsafe_ptr())
    )
    return DetailsJson(
        id=row.id,
        advertiser_id=row.advertiser_id,
        latitude=row.latitude,
        longitude=row.longitude,
        title=row.title,
        description=strip_html_to_text(row.description),
        street=String(""),
        house_number=row.house_number,
        complement=String(""),
        contact_phone=String(""),
        neighborhood=row.neighborhood,
        city=row.city,
        state=row.state,
        zip_code=String(""),
        period=row.period,
        daily_price=Price(row.daily_price),
        weekly_price=Price(row.weekly_price),
        monthly_price=Price(row.monthly_price),
        yearly_price=Price(row.yearly_price),
        hourly_price=Price(row.hourly_price),
        period_price=Price(row.period_price),
        prices_jsonb=optional_non_empty_raw_json(row.prices_jsonb),
        availability_jsonb=optional_non_empty_raw_json(row.availability_jsonb),
        owner_managed=optional_when(True, row.owner_managed),
        llm_title=row.llm_title.or_else(""),
        llm_description=row.llm_description.or_else(""),
        parent_listing_id=row.parent_listing_id,
        children_array=(
            Optional[Arr[Int64]](
                Arr[Int64](items=List[Int64](row.children.value().ids))
            ) if row.children else Optional[Arr[Int64]]()
        ),
        is_catalog=optional_when(True, row.is_catalog),
        duplicate_of=row.duplicate_of,
        source_offers_jsonb=optional_non_empty_raw_json(
            row.source_offers_jsonb
        ),
        created_at=TimestampMicros(
            parse_postgres_timestamp_bytes_lenient(
                created_at_pointer, len(created_at_bytes)
            )
        ),
        miles=Price(-1.0),
        filters=Arr[Int32](items=List[Int32](row.filters)),
        photos=photo_entries_from_list(row.photos),
        review_rate=row.review_rate,
        source_url=row.source_url.or_else(""),
        quality_score=row.quality_score,
        source=row.source.or_else(""),
        client_info=AlwaysNull(),
        median_rating=AlwaysNull(),
        is_favorite=0,
        count_total=0,
    )
