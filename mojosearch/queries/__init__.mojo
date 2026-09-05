"""Mojosearch queries — the raw comptime SQL statements of the search
domain and their frozen golden contracts, moved verbatim from the
application.

origin: alugue-mojo-api queries/
"""

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
    details_and_recommended_prepared_plan,
    nearby_prepared_plan,
    nearby_statement_name,
    recommended_statement_name,
)
