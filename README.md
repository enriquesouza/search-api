# mojosearch

The SEARCH domain library for the alugue stack: entities, search queries,
repositories/services, request binding, numeric parsing, taxonomy render and
the two-key nearby cache — everything the app's mojoflask layer needs to
serve nearby/details/recommended/filters. HTTP stays OUT: mojosearch exposes
serve-functions and plain structs; it is a domain library, NOT a web
framework (the web framework is mojoflask and lives in the application).

origin: alugue-mojo-api (models/, routes/nearby*, services/search/,
repositories/, queries/, cache/)

## Domain naming

Business terms (listing, nearby, filter, taxonomy, ...) are CORRECT here.
The generic-library naming law applies to the ecosystem packages only —
mojoflask, mojoserde, pqmojo, mojoka, mojolinq. This library is the place
where business names live.

## Module map

| Module | Role | Status |
|---|---|---|
| `mojosearch.entities` | search-side wire entities moved verbatim from the app (wire bytes frozen) | this scaffold |
| `mojosearch.web` | request binding + numeric parsing core (serving-path helpers) | sibling wave |
| `mojosearch.queries` | raw comptime SQL statements for the search domain | sibling wave |
| `mojosearch.services` | search services + taxonomy render | sibling wave |
| `mojosearch.cache` | the two-key nearby cache | sibling wave |
| `mojosearch.identity` | reserved | empty |

## Entities (this scaffold)

| Entity | Wire contract |
|---|---|
| `ListingJson` | nearby/recommended listing card element; WireSkips drop the empty `neighborhood`/`city`/`state`/`zip_code` fields and a null `quality_score` |
| `NearbyListingRow` | pqmojo `FromRow` row for the nearby prepared statement |
| `listing_json_from_nearby_row` | row-to-wire conversion (metres-to-miles, timestamp parse, photo entries) |
| `ListingCardJson` / `ListingCardRow` / `QualityRow` / `QualityJson` / `listing_card_from_row` | client listing cards with quality extras |
| `PhotoEntries` | gallery wire value: strips well-formed `N_` ordinal prefixes and re-emits entries in stable ordinal order |
| `Price` | business-shaped `Float64` wrapper writing the compact f64 wire form |
| `FilterNodeJson` / `LocalizedFilterJson` / `GroupedChildJson` / `GroupedChildLocalizedJson` | taxonomy render wire DTOs |

## Development

```bash
pixi run run-selftest      # golden-byte wire checks against app payloads
pixi run build-selftest
```

The selftest proves the entities serialize to the exact bytes captured in
the application's `payloads/nearby_300.json` golden payloads.

## License

MIT — see [LICENSE](LICENSE).
