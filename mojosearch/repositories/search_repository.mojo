from pqmojo import (
    ConnectionPool,
    FromRow,
    PoolConfig,
    format_i64,
    query_prepared_as,
)

from mojolinq import any, filter, for_each

from mojosearch.queries.plans import POOL_MODULE_DETAILS, POOL_MODULE_NEARBY

from mojosearch.queries.search_queries import (
    _assert_statement_goldens,
    _build_search_query_parameters,
    details_and_recommended_prepared_plan,
    nearby_prepared_plan,
    nearby_statement_name,
    recommended_statement_name,
)


comptime DETAILS_STATEMENT_NAME = "alugue_details"


def union_plan_lacks_statement(
    union_plan: List[Tuple[String, String]],
    statement_name: String,
) -> Bool:

    def union_entry_carries_statement_name(
        union_entry: Tuple[String, String],
    ) {imm statement_name} -> Bool:
        return union_entry[0] == statement_name

    return not any(union_plan, union_entry_carries_statement_name)


def fresh_module_plan_entries(
    union_plan: List[Tuple[String, String]],
    module_plan: List[Tuple[String, String]],
) -> List[Tuple[String, String]]:

    def union_plan_lacks_entry(
        entry: Tuple[String, String],
    ) {imm union_plan} -> Bool:
        return union_plan_lacks_statement(union_plan, entry[0])

    return filter(module_plan, union_plan_lacks_entry)


def append_missing_entries_into_union_plan(
    mut union_plan: List[Tuple[String, String]],
    module_plan: List[Tuple[String, String]],
) -> Bool:
    var fresh_entries = fresh_module_plan_entries(union_plan, module_plan)

    def append_entry_into_union_plan(
        entry: Tuple[String, String],
    ) {mut union_plan} -> None:
        union_plan.append(entry)

    for_each(fresh_entries, append_entry_into_union_plan)
    return len(fresh_entries) > 0


@fieldwise_init
struct SearchRepository(Movable):

    var database_url: String
    var pool: List[ConnectionPool]
    var union_plan: List[Tuple[String, String]]
    var armed_mask: Int

    def ensure_pool_ready(
        mut self,
        module_bit: Int,
        module_plan: List[Tuple[String, String]],
    ) raises -> Bool:
        if (self.armed_mask & module_bit) != 0:
            return True
        if len(self.pool) == 0:
            self.pool.append(
                ConnectionPool(
                    PoolConfig(
                        self.database_url,
                        max_size=2,
                        min_idle=1,
                        health_check=False,
                    )
                )
            )
        var grew_union_plan = append_missing_entries_into_union_plan(
            self.union_plan, module_plan
        )
        if grew_union_plan:
            self.pool[0].prepare_on_acquire(self.union_plan)
        self.armed_mask |= module_bit
        return True

    def details_rows[T: FromRow & Defaultable](
        mut self, listing_id: Int64
    ) raises -> List[T]:
        _ = self.ensure_pool_ready(
            POOL_MODULE_DETAILS, details_and_recommended_prepared_plan()
        )
        var parameters = List[String]()
        parameters.append(format_i64(listing_id))
        return query_prepared_as[T](
            self.pool[0],
            String(DETAILS_STATEMENT_NAME),
            parameters^,
        )

    def nearby_rows[T: FromRow & Defaultable](
        mut self,
        latitude: Float64,
        longitude: Float64,
        has_geo: Bool,
        window: Int,
        filter_ids: List[Int32],
        periods: List[UInt8],
    ) raises -> List[T]:
        _assert_statement_goldens()
        var has_filters = len(filter_ids) > 0
        var has_periods = len(periods) > 0
        _ = self.ensure_pool_ready(POOL_MODULE_NEARBY, nearby_prepared_plan())
        return query_prepared_as[T](
            self.pool[0],
            nearby_statement_name(has_geo, has_filters, has_periods),
            _build_search_query_parameters(
                latitude, longitude, window, filter_ids, periods
            ),
        )

    def recommended_rows[T: FromRow & Defaultable](
        mut self,
        latitude: Float64,
        longitude: Float64,
        has_geo: Bool,
        window: Int,
        filter_ids: List[Int32],
        periods: List[UInt8],
    ) raises -> List[T]:
        _assert_statement_goldens()
        var has_filters = len(filter_ids) > 0
        var has_periods = len(periods) > 0
        _ = self.ensure_pool_ready(
            POOL_MODULE_DETAILS, details_and_recommended_prepared_plan()
        )
        return query_prepared_as[T](
            self.pool[0],
            recommended_statement_name(has_geo, has_filters, has_periods),
            _build_search_query_parameters(
                latitude, longitude, window, filter_ids, periods
            ),
        )


def make_search_repository(database_url: String) -> SearchRepository:
    return SearchRepository(
        database_url=database_url,
        pool=List[ConnectionPool](),
        union_plan=List[Tuple[String, String]](),
        armed_mask=0,
    )
