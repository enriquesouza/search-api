"""mojosearch.web.serve_nearby_route — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/nearby/serve_nearby_route.mojo
"""

from mojoflask import DynamicOut

from mojoflask.incoming_request import IncomingRequest

from mojosearch.web.handlers import serve_nearby

from mojosearch.web.state_band import serve_published_state_family

from mojosearch.web.state_and_seed import NearbyState, STATE_ENV


def serve_nearby_route(
    request: IncomingRequest,
    mut out_buffer: DynamicOut,
) -> Bool:

    return serve_published_state_family[NearbyState, serve_nearby](
        STATE_ENV, request, out_buffer
    )
