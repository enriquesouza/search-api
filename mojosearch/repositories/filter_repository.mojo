from pqmojo import PgConn, exec_params


@fieldwise_init
struct FilterNode(Copyable, Movable):

    var id: Int64
    var name: String
    var name_en: String
    var name_es: String
    var parent: Int64
    var has_parent: Bool
    var has_name_en: Bool
    var has_name_es: Bool
    var is_active: Bool


from std.collections import Dict

from mojosearch.queries.taxonomy_sql import COUNTS_SQL, FILTERS_SQL


struct FilterRepository:
    @staticmethod
    def visible_nodes(connection: PgConn) raises -> List[FilterNode]:

        var nodes = List[FilterNode]()
        var filters_result = exec_params(
            connection, String(FILTERS_SQL), List[String]()
        )
        if filters_result.cols() != 8:
            filters_result.clear()
            raise Error(
                "taxonomy: FindAllActive returned "
                + String(filters_result.cols())
                + " columns, expected 8"
            )
        for row_index in range(filters_result.rows()):
            var node = FilterNode(
                id=filters_result.int64(row_index, 0),
                name=filters_result.text(row_index, 1),
                name_en=String(""),
                name_es=String(""),
                parent=filters_result.int64(row_index, 4),
                has_parent=not filters_result.is_null(row_index, 4),
                has_name_en=not filters_result.is_null(row_index, 2),
                has_name_es=not filters_result.is_null(row_index, 3),
                is_active=filters_result.text(row_index, 5).find("t") == 0,
            )
            if node.has_name_en:
                node.name_en = filters_result.text(row_index, 2)
            if node.has_name_es:
                node.name_es = filters_result.text(row_index, 3)
            nodes.append(node^)
        filters_result.clear()
        return nodes^

    @staticmethod
    def counts(connection: PgConn) raises -> Dict[Int64, Int64]:

        var counts = Dict[Int64, Int64]()
        try:
            var counts_result = exec_params(
                connection, String(COUNTS_SQL), List[String]()
            )
            if counts_result.cols() == 2:
                for row_index in range(counts_result.rows()):
                    counts[
                        counts_result.int64(row_index, 0)
                    ] = counts_result.int64(row_index, 1)
            counts_result.clear()
        except:
            pass
        return counts^
