"""mojosearch.entities.listing_card — client listing-card wire entities.

origin: alugue-mojo-api models/listing_card.mojo
"""

from pqmojo import FromRow, RowColumns, format_i64

from mojolinq import find

from mojosearch.entities.photo_entries import (
    PhotoEntries,
    optional_photo_entries_from_optional_list,
)
from mojoserde import RawJson


struct ListingCardRow(Copyable, Defaultable, FromRow, Movable):

    var id: Int64
    var title: String
    var period: Optional[String]
    var is_active: Bool
    var period_price: Float64
    var photos: Optional[List[String]]
    var review_rate: Int32

    def __init__(out self):
        self.id = 0
        self.title = String("")
        self.period = Optional[String]()
        self.is_active = False
        self.period_price = 0
        self.photos = Optional[List[String]]()
        self.review_rate = 0

    @staticmethod
    def row_columns() raises -> RowColumns:
        var column_list = RowColumns()
        column_list.add("id")
        column_list.add("title")
        column_list.add("period")
        column_list.add("is_active")
        column_list.add("")
        column_list.add("photos_array")
        column_list.add("review_rate")
        return column_list^


struct QualityRow(Copyable, Defaultable, FromRow, ImplicitlyCopyable, Movable):

    var listing_id: Optional[Int64]
    var score: Optional[Int32]
    var grade: Optional[String]
    var breakdown: Optional[String]
    var parent_listing_id: Optional[Int64]
    var scored_at: Optional[String]

    def __init__(out self):
        self.listing_id = Optional[Int64]()
        self.score = Optional[Int32]()
        self.grade = Optional[String]()
        self.breakdown = Optional[String]()
        self.parent_listing_id = Optional[Int64]()
        self.scored_at = Optional[String]()

    @staticmethod
    def row_columns() raises -> RowColumns:
        var column_list = RowColumns()
        column_list.add("id")
        column_list.add("quality_score")
        column_list.add("quality_grade")
        column_list.add("quality_jsonb")
        column_list.add("parent_listing_id")
        column_list.add("to_char")
        return column_list^


@fieldwise_init
struct QualityJson(Copyable, Movable):

    var parent_listing_id: Optional[Int64]
    var score: Optional[Int32]
    var grade: Optional[String]
    var breakdown: Optional[RawJson]
    var scored_at: Optional[String]


@fieldwise_init
struct ListingCardJson(Copyable, Movable):

    var id: Int64
    var title: String
    var period: Optional[String]
    var is_active: Bool
    var period_price: Float64
    var photos: Optional[PhotoEntries]
    var review_rate: Int32
    var quality: Optional[QualityJson]
    var parent_listing_id: Optional[Int64]


def _quality_json_of(imm row: QualityRow) -> QualityJson:

    var breakdown_field = Optional[RawJson]()
    if row.breakdown:
        breakdown_field = Optional[RawJson](RawJson(row.breakdown.value()))
    return QualityJson(
        parent_listing_id=row.parent_listing_id,
        score=row.score,
        grade=row.grade,
        breakdown=breakdown_field^,
        scored_at=row.scored_at,
    )


def listing_card_from_row(
    imm row: ListingCardRow, imm extras: List[QualityRow]
) raises -> ListingCardJson:

    var photos_field = optional_photo_entries_from_optional_list(row.photos)
    var quality_field = Optional[QualityJson]()
    var parent_field = Optional[Int64]()
    var id_text = format_i64(row.id)

    def extras_row_belongs_to_listing(
        extras_row: QualityRow,
    ) {id_text} -> Bool:
        if extras_row.listing_id:
            return format_i64(extras_row.listing_id.value()) == id_text
        return False

    var matched_extras_row = find(extras, extras_row_belongs_to_listing)
    if matched_extras_row:
        quality_field = Optional[QualityJson](
            _quality_json_of(matched_extras_row.value())
        )
        parent_field = matched_extras_row.value().parent_listing_id
    return ListingCardJson(
        id=row.id,
        title=row.title,
        period=row.period,
        is_active=row.is_active,
        period_price=row.period_price,
        photos=photos_field^,
        review_rate=row.review_rate,
        quality=quality_field^,
        parent_listing_id=parent_field^,
    )
