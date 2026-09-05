# mojosearch

The SEARCH domain library for the alugue stack: entities, search queries,
repositories, services, request binding, numeric parsing, taxonomy render
and the two-key nearby cache — everything the app's mojoflask layer needs
to serve nearby/details/recommended/filters. HTTP stays OUT: mojosearch
exposes serve-functions and plain structs; it is a domain library, NOT a
web framework (the web framework is mojoflask and lives in the application).

origin: alugue-mojo-api (models/, routes/nearby*, handlers/search/,
services/search/, repositories/, queries/, cache/)

## Domain naming

Business terms (listing, nearby, filter, taxonomy, ...) are CORRECT here.
The generic-library naming law applies to the ecosystem packages only —
mojoflask, mojoserde, pqmojo, mojoka, mojolinq. This library is the place
where business names live.

## Module map (complete at v0.1.0)

| Module | Role |
|---|---|
| `mojosearch.entities` | search-side wire entities moved verbatim from the app, wire bytes frozen: nearby/recommended cards (`ListingJson`), client cards (`ListingCardJson`), details (`DetailsJson` + `ListingDetailsRow`/`details_out_of`), the response envelope (`OkResponseWrapperJson`/`ERROR_BODY`), gallery (`PhotoEntries`), compact price (`Price`), taxonomy wire DTOs — plus the frozen HTML-to-text scanner (`html_to_text` + the generated `entities_tbl`) behind the details description |
| `mojosearch.queries` | raw comptime SQL statements: the 16 built nearby/recommended variants (`BUILT_S_*`/`BUILT_R_*` golden contracts), `DETAILS_SQL`, the prepared plans and frozen statement-name composition (`alugue_nb_*`/`alugue_rec_*`/`alugue_details`), pool-module bits + `SearchRowPlan` |
| `mojosearch.repositories` | `SearchRepository` (lazy pqmojo pool, prepared-statement union plan, typed `query_prepared_as` rows) and `FilterRepository`/`FilterNode` |
| `mojosearch.services` | `SearchService` (nearby/recommended/details reads over the repository + two-key cache), taxonomy render/service/state, `NearbyRequest` |
| `mojosearch.web` | the serving surface: request binding (`bind_nearby_request`), numeric parsing core, market-code scan, envelope writers, IncomingRequest serve resolvers (`serve_nearby_route`, `serve_listing_details_route`, `serve_recommended_listings_route`, `resolve_filters`), state slots (`NearbyState`/`HotReadState`/taxonomy) with env-identity constants and the seed function |
| `mojosearch.cache` | the two-key nearby response cache (`NearbyResponseCache`: identity key + brotli variant key over an mmap slot table) |
| `mojosearch.cache_keys` | the frozen cache-key derivation: grid-cell rounding for coordinates and the request key append (`MAX_RESULTS`, `KEY_SEPARATOR_PIPE`) |

Two-tier API: everything above re-exports at the root (`from mojosearch
import ...`); the 16 frozen golden statements are additionally reachable at
`mojosearch.queries` (`BUILT_S_*`/`BUILT_R_*`).

## Entities wire contracts

| Entity | Wire contract |
|---|---|
| `ListingJson` | nearby/recommended listing card element; WireSkips drop the empty `neighborhood`/`city`/`state`/`zip_code` fields and a null `quality_score` |
| `NearbyListingRow` | pqmojo `FromRow` row for the nearby prepared statement |
| `listing_json_from_nearby_row` | row-to-wire conversion (metres-to-miles, timestamp parse, photo entries) |
| `ListingCardJson` / `ListingCardRow` / `QualityRow` / `QualityJson` / `listing_card_from_row` | client listing cards with quality extras |
| `DetailsJson` / `ListingDetailsRow` / `ChildrenIds` / `details_out_of` | the details page wire entity, its 34-column row and the row-to-wire conversion (HTML description stripped through the frozen scanner) |
| `OkResponseWrapperJson` / `ERROR_BODY` | the generic response envelope and the canonical error body |
| `PhotoEntries` | gallery wire value: strips well-formed `N_` ordinal prefixes and re-emits entries in stable ordinal order |
| `Price` | business-shaped `Float64` wrapper writing the compact f64 wire form |
| `FilterNodeJson` / `LocalizedFilterJson` / `GroupedChildJson` / `GroupedChildLocalizedJson` | taxonomy render wire DTOs |

## Development

```bash
pixi run run-selftest            # queries/repository goldens + arming pattern
pixi run run-entities-selftest   # entity wire proofs vs app golden bytes
pixi run run-strip-test          # HTML-to-text scanner vector suite
pixi run precompile              # whole-package compile gate
```

Other suites (run with `pixi run mojo run -I . <file>`):
`tests/web_binding_test.mojo`, `tests/web_envelope_golden_test.mojo`,
`tests/web_numeric_core_test.mojo`, `tests/cache_two_key_test.mojo`,
`tests/taxonomy_render_test.mojo`. `tests/golden_nearby.mojo` is the
golden-fixture helper library the entities selftest imports.

The entities selftest proves the moved entities serialize to the exact
bytes captured in the application's `payloads/nearby_300.json` golden
payloads (regenerate fixtures with `python3 tools/gen_fixture_literals.py`).

## License

MIT — see [LICENSE](LICENSE).
