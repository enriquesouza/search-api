"""Mojosearch repositories — the search-side repositories over pqmojo
pools, moved verbatim from the application.

origin: alugue-mojo-api repositories/
"""

from mojosearch.repositories.filter_repository import (
    FilterNode,
    FilterRepository,
)
from mojosearch.repositories.search_repository import (
    DETAILS_STATEMENT_NAME,
    SearchRepository,
    append_missing_entries_into_union_plan,
    fresh_module_plan_entries,
    make_search_repository,
    union_plan_lacks_statement,
)
