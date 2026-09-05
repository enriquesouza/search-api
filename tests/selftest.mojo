"""Selftest for mojosearch — golden statement proofs, frozen plan-name contracts, and the repository arming pattern."""

from pqmojo import FromRow, RowColumns

from mojosearch.queries.plans import (
    POOL_MODULE_DETAILS,
    POOL_MODULE_NEARBY,
    SearchRowPlan,
)

from mojosearch.queries.search_queries import (
    BUILT_R_GFN,
    BUILT_R_GNN,
    BUILT_R_GNY,
    BUILT_R_GFY,
    BUILT_R_PFN,
    BUILT_R_PNN,
    BUILT_R_PNY,
    BUILT_R_PFY,
    BUILT_S_GFN,
    BUILT_S_GNN,
    BUILT_S_GNY,
    BUILT_S_GFY,
    BUILT_S_PFN,
    BUILT_S_PNN,
    BUILT_S_PNY,
    BUILT_S_PFY,
    DETAILS_SQL,
    _assert_statement_goldens,
    details_and_recommended_prepared_plan,
    nearby_prepared_plan,
    nearby_statement_name,
    recommended_statement_name,
)

from mojosearch.repositories.search_repository import (
    SearchRepository,
    append_missing_entries_into_union_plan,
    make_search_repository,
    union_plan_lacks_statement,
)


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error("mojosearch selftest failed: " + message)


struct ProbeRow(Copyable, Defaultable, FromRow, Movable):

    var identifier: Int64
    var heading: String
    var distance: Float64

    def __init__(out self):
        self.identifier = 0
        self.heading = String("")
        self.distance = 0

    @staticmethod
    def row_columns() raises -> RowColumns:
        var column_list = RowColumns()
        column_list.add("id")
        column_list.add("title")
        column_list.add("distance")
        return column_list^


def compile_proof_repository_fetch_chain(
    mut search_repository: SearchRepository,
) raises -> List[ProbeRow]:
    var nearby_rows = search_repository.nearby_rows[ProbeRow](
        0.0, 0.0, False, 50, List[Int32](), List[UInt8]()
    )
    var recommended_rows = search_repository.recommended_rows[ProbeRow](
        0.0, 0.0, False, 50, List[Int32](), List[UInt8]()
    )
    var details_rows = search_repository.details_rows[ProbeRow](1)
    _ = nearby_rows
    _ = recommended_rows
    return details_rows^


def check_prepared_plan_entry(
    plan_entry: Tuple[String, String],
    expected_statement_name: String,
    expected_sql_statement: String,
) raises:
    check(
        plan_entry[0] == expected_statement_name,
        "prepared plan entry carries statement name "
        + expected_statement_name
        + " but found "
        + plan_entry[0],
    )
    check(
        plan_entry[1] == expected_sql_statement,
        "prepared plan entry SQL drifted for statement "
        + expected_statement_name,
    )


def check_golden_statements() raises:
    _assert_statement_goldens()
    print("goldens: 16/16 built statements byte-match their frozen goldens")


def check_nearby_prepared_plan_contract() raises:
    var nearby_plan = nearby_prepared_plan()
    check(len(nearby_plan) == 8, "nearby prepared plan holds 8 statements")
    check_prepared_plan_entry(nearby_plan[0], "alugue_nb_000", BUILT_S_PNN)
    check_prepared_plan_entry(nearby_plan[1], "alugue_nb_001", BUILT_S_PNY)
    check_prepared_plan_entry(nearby_plan[2], "alugue_nb_010", BUILT_S_PFN)
    check_prepared_plan_entry(nearby_plan[3], "alugue_nb_011", BUILT_S_PFY)
    check_prepared_plan_entry(nearby_plan[4], "alugue_nb_100", BUILT_S_GNN)
    check_prepared_plan_entry(nearby_plan[5], "alugue_nb_101", BUILT_S_GNY)
    check_prepared_plan_entry(nearby_plan[6], "alugue_nb_110", BUILT_S_GFN)
    check_prepared_plan_entry(nearby_plan[7], "alugue_nb_111", BUILT_S_GFY)
    print("nearby plan: 8 frozen statement names in frozen order")


def check_details_and_recommended_prepared_plan_contract() raises:
    var details_plan = details_and_recommended_prepared_plan()
    check(
        len(details_plan) == 9,
        "details and recommended prepared plan holds 9 statements",
    )
    check_prepared_plan_entry(details_plan[0], "alugue_details", DETAILS_SQL)
    check_prepared_plan_entry(details_plan[1], "alugue_rec_000", BUILT_R_PNN)
    check_prepared_plan_entry(details_plan[2], "alugue_rec_001", BUILT_R_PNY)
    check_prepared_plan_entry(details_plan[3], "alugue_rec_010", BUILT_R_PFN)
    check_prepared_plan_entry(details_plan[4], "alugue_rec_011", BUILT_R_PFY)
    check_prepared_plan_entry(details_plan[5], "alugue_rec_100", BUILT_R_GNN)
    check_prepared_plan_entry(details_plan[6], "alugue_rec_101", BUILT_R_GNY)
    check_prepared_plan_entry(details_plan[7], "alugue_rec_110", BUILT_R_GFN)
    check_prepared_plan_entry(details_plan[8], "alugue_rec_111", BUILT_R_GFY)
    print("details plan: alugue_details + 8 recommended names in frozen order")


def check_statement_name_composition() raises:
    check(
        nearby_statement_name(False, False, False) == "alugue_nb_000",
        "nearby statement name composes the flag digits geo-filters-periods",
    )
    check(
        nearby_statement_name(True, True, True) == "alugue_nb_111",
        "nearby statement name composes all-true flags as 111",
    )
    check(
        recommended_statement_name(False, True, False) == "alugue_rec_010",
        "recommended statement name composes the flag digits geo-filters-periods",
    )
    check(
        recommended_statement_name(True, False, True) == "alugue_rec_101",
        "recommended statement name composes alternating flags as 101",
    )
    print("statement names: composition digit order frozen (geo-filters-periods)")


def check_search_row_plan_defaults() raises:
    var search_row_plan = SearchRowPlan()
    check(
        not search_row_plan.resolved,
        "a fresh SearchRowPlan starts unresolved",
    )
    check(
        POOL_MODULE_NEARBY == 2 and POOL_MODULE_DETAILS == 4,
        "search pool module bits stay frozen at the app's arming values",
    )
    print("plans: SearchRowPlan defaults and pool module bits frozen")


def check_repository_arming_pattern() raises:
    var search_repository = make_search_repository(
        "postgresql://search:selftest@127.0.0.1:1/none"
    )
    check(
        len(search_repository.pool) == 0,
        "make_search_repository opens no connection (pool is lazy until first arm)",
    )
    check(search_repository.armed_mask == 0, "fresh repository arms nothing")
    check(
        len(search_repository.union_plan) == 0,
        "fresh repository holds an empty union plan",
    )

    var union_plan = List[Tuple[String, String]]()
    var first_arm_grew_union = append_missing_entries_into_union_plan(
        union_plan, nearby_prepared_plan()
    )
    check(first_arm_grew_union, "first nearby arm grows the union plan")
    check(len(union_plan) == 8, "nearby arm contributes exactly 8 statements")

    var rearm_grew_union = append_missing_entries_into_union_plan(
        union_plan, nearby_prepared_plan()
    )
    check(
        not rearm_grew_union,
        "re-arming the same module plan adds no duplicate statements",
    )
    check(
        len(union_plan) == 8,
        "union plan stays at 8 statements after the repeated arm",
    )

    var details_arm_grew_union = append_missing_entries_into_union_plan(
        union_plan, details_and_recommended_prepared_plan()
    )
    check(details_arm_grew_union, "details arm grows the union plan")
    check(
        len(union_plan) == 17,
        "union plan reaches 17 statements across both search module plans",
    )
    check(
        not union_plan_lacks_statement(union_plan, "alugue_details"),
        "union plan holds the details statement after the details arm",
    )
    check(
        union_plan_lacks_statement(union_plan, "statement_from_another_module"),
        "union plan misses statements outside the search plans",
    )
    print(
        "repository arming: lazy pool, 8+9 union plan growth, duplicate-free re-arm"
    )


def main() raises:
    check_golden_statements()
    check_nearby_prepared_plan_contract()
    check_details_and_recommended_prepared_plan_contract()
    check_statement_name_composition()
    check_search_row_plan_defaults()
    check_repository_arming_pattern()
    print("ALL MOJOSEARCH SELFTEST SECTIONS GREEN")
