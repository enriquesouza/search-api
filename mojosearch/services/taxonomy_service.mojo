from mojoflask import ResponseBuffer

from pqmojo import PgConn

from std.collections import Dict

from mojosearch.repositories.filter_repository import FilterNode

from mojosearch.repositories.filter_repository import FilterRepository

from mojosearch.services.taxonomy_state import TaxonomyState


@fieldwise_init
struct FiltersQuery(Copyable):

    var flat_request_mode: Int
    var has_language_tag: Bool
    var resolved_language: Int


struct TaxonomyService:
    @staticmethod
    def visible_nodes(connection: PgConn) raises -> List[FilterNode]:

        return FilterRepository.visible_nodes(connection)

    @staticmethod
    def counts(connection: PgConn) raises -> Dict[Int64, Int64]:

        return FilterRepository.counts(connection)

    @staticmethod
    def filters_response_for_query(
        taxonomy_state: TaxonomyState, filter_query: FiltersQuery
    ) -> ResponseBuffer:

        if not taxonomy_state.live:
            return taxonomy_state.response_erroror
        if filter_query.flat_request_mode == 3:
            return taxonomy_state.response_bad_query_string
        if filter_query.flat_request_mode == 4:
            return taxonomy_state.response_duplicate_field
        if filter_query.flat_request_mode == 1:
            return taxonomy_state.response_flat
        return taxonomy_state.response_grouped
