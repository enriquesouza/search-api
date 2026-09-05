comptime FILTERS_SQL = (
    "SELECT id, name, name_en, name_es, parent_filter_id, is_active, created_at, updated_at"
    " FROM filter WHERE is_active=true ORDER BY id"
)

comptime COUNTS_SQL = """SELECT
			f.id,
			count(l.id)::int8 AS n
		FROM
			public.filter f
			LEFT JOIN public.listing_active l ON l.is_active
			AND l.filters_array @> ARRAY[f.id]
		WHERE
			f.parent_filter_id IS NOT NULL
		GROUP BY
			f.id"""
