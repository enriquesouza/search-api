from pqmojo import (
    PgConn,
    connect,
    format_f64,
    format_i64,
    gss_safe_dsn,
    int_array_literal,
    letter_array_literal,
)

from mojolinq import flat_map, for_each, map_elements


comptime SEARCH_COLUMNS = """id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4"""

comptime GEO_METERS = "ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography)"

comptime GEO_ORDER = "(geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326))"

comptime PLAIN_DISTANCE = "($1::float8 * 0 + $2::float8 * 0)"

comptime PERIODS_CLAUSE_4 = """
	and ((
            'H' = ANY($4::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($4::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($4::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($4::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($4::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($4::text[])
            and period = 'P'
        ))"""

comptime PERIODS_CLAUSE_5 = """
	and ((
            'H' = ANY($5::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($5::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($5::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($5::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($5::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($5::text[])
            and period = 'P'
        ))"""


def _build_search_sql_statement(
    has_geo: Bool, has_filters: Bool, has_periods: Bool, quality_first: Bool
) -> String:

    var where_line_separator = "\n\t" if has_geo else "\n "
    var where = ""
    if quality_first:
        where += "cardinality(photos_array) > 0" + where_line_separator + "and "
    where += "is_active" + where_line_separator + "and NOT provider_hidden"
    if has_filters:
        where += where_line_separator + "and filters_array @> $4"
    if has_periods:
        where += PERIODS_CLAUSE_5 if has_filters else PERIODS_CLAUSE_4

    var distance = PLAIN_DISTANCE
    var order = " quality_score DESC NULLS LAST,\n id"
    if has_geo:
        distance = GEO_METERS
        order = " " + GEO_ORDER + ", quality_score DESC NULLS LAST,\n id"
    var head = (
        """select
 """ + SEARCH_COLUMNS + """,
 null::text as client_info,
 """
        + distance + """ as distance
from
 listing_active
where
 """
    )
    if quality_first:
        order = "quality_score DESC NULLS LAST"
        if has_geo:
            order = "quality_score DESC NULLS LAST, " + GEO_ORDER
        return head + where + "\norder by\n " + order + ",\n id\nlimit $3"
    return head + where + "\norder by" + order + "\nlimit $3"


comptime EXPECTED_S_PNN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 is_active
 and NOT provider_hidden
order by quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_PNN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
 and is_active
 and NOT provider_hidden
order by
 quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_S_PNY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 is_active
 and NOT provider_hidden
	and ((
            'H' = ANY($4::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($4::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($4::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($4::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($4::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($4::text[])
            and period = 'P'
        ))
order by quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_PNY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
 and is_active
 and NOT provider_hidden
	and ((
            'H' = ANY($4::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($4::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($4::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($4::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($4::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($4::text[])
            and period = 'P'
        ))
order by
 quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_S_PFN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 is_active
 and NOT provider_hidden
 and filters_array @> $4
order by quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_PFN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
 and is_active
 and NOT provider_hidden
 and filters_array @> $4
order by
 quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_S_PFY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 is_active
 and NOT provider_hidden
 and filters_array @> $4
	and ((
            'H' = ANY($5::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($5::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($5::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($5::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($5::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($5::text[])
            and period = 'P'
        ))
order by quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_PFY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ($1::float8 * 0 + $2::float8 * 0) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
 and is_active
 and NOT provider_hidden
 and filters_array @> $4
	and ((
            'H' = ANY($5::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($5::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($5::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($5::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($5::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($5::text[])
            and period = 'P'
        ))
order by
 quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_S_GNN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 is_active
	and NOT provider_hidden
order by (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)), quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_GNN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
	and is_active
	and NOT provider_hidden
order by
 quality_score DESC NULLS LAST, (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)),
 id
limit $3"""
comptime EXPECTED_S_GNY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 is_active
	and NOT provider_hidden
	and ((
            'H' = ANY($4::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($4::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($4::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($4::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($4::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($4::text[])
            and period = 'P'
        ))
order by (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)), quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_GNY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
	and is_active
	and NOT provider_hidden
	and ((
            'H' = ANY($4::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($4::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($4::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($4::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($4::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($4::text[])
            and period = 'P'
        ))
order by
 quality_score DESC NULLS LAST, (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)),
 id
limit $3"""
comptime EXPECTED_S_GFN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 is_active
	and NOT provider_hidden
	and filters_array @> $4
order by (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)), quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_GFN = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
	and is_active
	and NOT provider_hidden
	and filters_array @> $4
order by
 quality_score DESC NULLS LAST, (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)),
 id
limit $3"""
comptime EXPECTED_S_GFY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 is_active
	and NOT provider_hidden
	and filters_array @> $4
	and ((
            'H' = ANY($5::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($5::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($5::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($5::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($5::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($5::text[])
            and period = 'P'
        ))
order by (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)), quality_score DESC NULLS LAST,
 id
limit $3"""
comptime EXPECTED_R_GFY = """select
 id, advertiser_id, latitude, longitude, title, NULL::text AS description,
        street, house_number, complement, NULL::text AS contact_phone, NULL::text AS neighborhood,
        NULL::text AS city, NULL::text AS state, NULL::text AS zip_code, period, daily_price::float8,
        weekly_price::float8, monthly_price::float8, yearly_price::float8, hourly_price::float8,
        period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        NULL::text AS source_url, NULL::text AS source, quality_score::int4,
 null::text as client_info,
 ST_Distance(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance
from
 listing_active
where
 cardinality(photos_array) > 0
	and is_active
	and NOT provider_hidden
	and filters_array @> $4
	and ((
            'H' = ANY($5::text[])
            and hourly_price > 0
        )
            or (
            'D' = ANY($5::text[])
            and daily_price > 0
        )
            or (
            'S' = ANY($5::text[])
            and weekly_price > 0
        )
            or (
            'M' = ANY($5::text[])
            and monthly_price > 0
        )
            or (
            'Y' = ANY($5::text[])
            and yearly_price > 0
        )
            or (
            'P' = ANY($5::text[])
            and period = 'P'
        ))
order by
 quality_score DESC NULLS LAST, (geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)),
 id
limit $3"""

comptime BUILT_S_PNN = _build_nearby_sql_statement(False, False, False)
comptime BUILT_S_PFN = _build_nearby_sql_statement(False, True, False)
comptime BUILT_S_PNY = _build_nearby_sql_statement(False, False, True)
comptime BUILT_S_PFY = _build_nearby_sql_statement(False, True, True)
comptime BUILT_S_GNN = _build_nearby_sql_statement(True, False, False)
comptime BUILT_S_GFN = _build_nearby_sql_statement(True, True, False)
comptime BUILT_S_GNY = _build_nearby_sql_statement(True, False, True)
comptime BUILT_S_GFY = _build_nearby_sql_statement(True, True, True)
comptime BUILT_R_PNN = _build_recommended_sql_statement(False, False, False)
comptime BUILT_R_PFN = _build_recommended_sql_statement(False, True, False)
comptime BUILT_R_PNY = _build_recommended_sql_statement(False, False, True)
comptime BUILT_R_PFY = _build_recommended_sql_statement(False, True, True)
comptime BUILT_R_GNN = _build_recommended_sql_statement(True, False, False)
comptime BUILT_R_GFN = _build_recommended_sql_statement(True, True, False)
comptime BUILT_R_GNY = _build_recommended_sql_statement(True, False, True)
comptime BUILT_R_GFY = _build_recommended_sql_statement(True, True, True)


@always_inline
def _assert_statement_goldens() raises:

    if BUILT_S_PNN != EXPECTED_S_PNN:
        raise Error("listing_search_queries: golden drift S_PNN")
    if BUILT_S_PFN != EXPECTED_S_PFN:
        raise Error("listing_search_queries: golden drift S_PFN")
    if BUILT_S_PNY != EXPECTED_S_PNY:
        raise Error("listing_search_queries: golden drift S_PNY")
    if BUILT_S_PFY != EXPECTED_S_PFY:
        raise Error("listing_search_queries: golden drift S_PFY")
    if BUILT_S_GNN != EXPECTED_S_GNN:
        raise Error("listing_search_queries: golden drift S_GNN")
    if BUILT_S_GFN != EXPECTED_S_GFN:
        raise Error("listing_search_queries: golden drift S_GFN")
    if BUILT_S_GNY != EXPECTED_S_GNY:
        raise Error("listing_search_queries: golden drift S_GNY")
    if BUILT_S_GFY != EXPECTED_S_GFY:
        raise Error("listing_search_queries: golden drift S_GFY")
    if BUILT_R_PNN != EXPECTED_R_PNN:
        raise Error("listing_search_queries: golden drift R_PNN")
    if BUILT_R_PFN != EXPECTED_R_PFN:
        raise Error("listing_search_queries: golden drift R_PFN")
    if BUILT_R_PNY != EXPECTED_R_PNY:
        raise Error("listing_search_queries: golden drift R_PNY")
    if BUILT_R_PFY != EXPECTED_R_PFY:
        raise Error("listing_search_queries: golden drift R_PFY")
    if BUILT_R_GNN != EXPECTED_R_GNN:
        raise Error("listing_search_queries: golden drift R_GNN")
    if BUILT_R_GFN != EXPECTED_R_GFN:
        raise Error("listing_search_queries: golden drift R_GFN")
    if BUILT_R_GNY != EXPECTED_R_GNY:
        raise Error("listing_search_queries: golden drift R_GNY")
    if BUILT_R_GFY != EXPECTED_R_GFY:
        raise Error("listing_search_queries: golden drift R_GFY")




def _build_nearby_sql_statement(
    has_coordinates_present: Bool,
    has_filters: Bool,
    has_periods: Bool,
) -> String:
    return _build_search_sql_statement(
        has_coordinates_present, has_filters, has_periods, False,
    )


def _build_recommended_sql_statement(
    has_coordinates_present: Bool,
    has_filters: Bool,
    has_periods: Bool,
) -> String:
    return _build_search_sql_statement(
        has_coordinates_present, has_filters, has_periods, True,
    )

def open_connection_after_fork(conninfo: String) raises -> PgConn:

    return connect(gss_safe_dsn(conninfo))


def _variant_flag(has_geo: Bool, has_filters: Bool, has_periods: Bool) -> String:

    return ("1" if has_geo else "0") + ("1" if has_filters else "0") + (
        "1" if has_periods else "0"
    )


def nearby_statement_name(has_geo: Bool, has_filters: Bool, has_periods: Bool) -> String:

    return String("alugue_nb_") + _variant_flag(has_geo, has_filters, has_periods)


def recommended_statement_name(has_geo: Bool, has_filters: Bool, has_periods: Bool) -> String:

    return String("alugue_rec_") + _variant_flag(has_geo, has_filters, has_periods)


def variant_flag_choices() -> List[Bool]:

    var choices = List[Bool](capacity=2)
    choices.append(False)
    choices.append(True)
    return choices^


def variant_flag_pairs() -> List[Tuple[Bool, Bool]]:

    def pairs_of_first_choice(
        first_flag: Bool,
    ) -> List[Tuple[Bool, Bool]]:

        def pair_of_second_choice(
            second_flag: Bool,
        ) {imm} -> Tuple[Bool, Bool]:
            return (first_flag, second_flag)

        return map_elements(variant_flag_choices(), pair_of_second_choice)

    return flat_map(variant_flag_choices(), pairs_of_first_choice)


def _plan_entry_of_variant(
    recommended: Bool, has_geo: Bool, has_filters: Bool, has_periods: Bool
) -> Tuple[String, String]:

    if recommended:
        return (
            recommended_statement_name(has_geo, has_filters, has_periods),
            _build_recommended_sql_statement(
                has_geo, has_filters, has_periods
            ),
        )
    return (
        nearby_statement_name(has_geo, has_filters, has_periods),
        _build_nearby_sql_statement(has_geo, has_filters, has_periods),
    )


def _append_statement_plan_entries(
    mut plan: List[Tuple[String, String]], recommended: Bool
):

    def filter_and_period_variants_of_geo_choice(
        has_geo: Bool,
    ) {imm} -> List[Tuple[String, String]]:

        def plan_entry_of_flag_pair(
            flag_pair: Tuple[Bool, Bool],
        ) {imm} -> Tuple[String, String]:
            var has_filters = flag_pair[0]
            var has_periods = flag_pair[1]
            return _plan_entry_of_variant(
                recommended, has_geo, has_filters, has_periods
            )

        return map_elements(variant_flag_pairs(), plan_entry_of_flag_pair)

    var plan_entries = flat_map(
        variant_flag_choices(), filter_and_period_variants_of_geo_choice
    )

    def append_entry_into_plan(
        entry: Tuple[String, String],
    ) {mut plan} -> None:
        plan.append(entry)

    for_each(plan_entries, append_entry_into_plan)


def nearby_prepared_plan() -> List[Tuple[String, String]]:

    var plan = List[Tuple[String, String]]()
    _append_statement_plan_entries(plan, False)
    return plan^


def details_and_recommended_prepared_plan() -> List[Tuple[String, String]]:

    var plan = List[Tuple[String, String]]()
    plan.append((String("alugue_details"), DETAILS_SQL))
    _append_statement_plan_entries(plan, True)
    return plan^


def _build_search_query_parameters(
    latitude: Float64,
    longitude: Float64,
    window: Int,
    filter_ids: List[Int32],
    periods: List[UInt8],
) -> List[String]:

    var parameters = List[String]()
    parameters.append(format_f64(latitude))
    parameters.append(format_f64(longitude))
    parameters.append(format_i64(Int64(window)))
    if len(filter_ids) > 0:
        parameters.append(int_array_literal(filter_ids))
    if len(periods) > 0:
        parameters.append(letter_array_literal(periods))
    return parameters^


comptime DETAILS_COLUMNS = """id, advertiser_id, latitude, longitude, title, description,
        NULL::text AS street, NULL::int4 AS house_number, NULL::text AS complement,
        NULL::text AS contact_phone, neighborhood, city, state, NULL::text AS zip_code,
        period, daily_price::float8, weekly_price::float8, monthly_price::float8, yearly_price::float8,
        hourly_price::float8, period_price::float8, data_anuncio::text, filters_array, photos_array, review_rate,
        source_url, source, quality_score::int4"""

comptime DETAILS_SQL = (
    """select
 """ + DETAILS_COLUMNS + """,
 null::text as client_info,
 0::float8 as distance,
 prices_jsonb::text, availability_jsonb::text,
 (source IS NULL OR source = '') AS owner_managed,
 llm_title, llm_description,
 parent_listing_id, children_array::text, is_catalog,
 duplicate_of, source_offers_jsonb::text
from
 listing_active
where
 id = $1
 and (is_active OR duplicate_of IS NOT NULL)
 and NOT provider_hidden
limit 1"""
)
