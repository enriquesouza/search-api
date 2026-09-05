"""Mojosearch — the SEARCH domain library: entities, queries, services and
the two-key nearby cache, served behind the application's mojoflask layer.

origin: alugue-mojo-api (models/, routes/nearby*, services/search/,
repositories/, queries/, cache/)

Boundary: this library exposes serve-functions and plain structs. HTTP
stays OUT — mojoflask in the application is the web framework; mojosearch
is the domain.

Public API (landing wave by wave):
    entities   search-side wire entities, wire bytes frozen (landed)
    web        request binding + numeric parsing core (sibling wave)
    queries    raw comptime SQL statements (sibling wave)
    services   search services + taxonomy render (sibling wave)
    cache      the two-key nearby cache (sibling wave)
"""

from mojosearch.entities import (
    FilterNodeJson,
    GroupedChildJson,
    GroupedChildLocalizedJson,
    ListingCardJson,
    ListingCardRow,
    ListingJson,
    LocalizedFilterJson,
    NearbyListingRow,
    PhotoEntries,
    Price,
    QualityJson,
    QualityRow,
    decode_photo_entry,
    listing_card_from_row,
    listing_json_from_nearby_row,
    optional_photo_entries_from_optional_list,
    photo_entries_from_list,
)
