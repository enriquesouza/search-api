"""mojosearch.web.state_band — moved verbatim from the application, wire bytes frozen.

origin: alugue-mojo-api routes/_state_band.mojo
"""

from mojoflask import DynamicOut

from mojoflask.incoming_request import IncomingRequest

from mojoflask.statemod import (
    StateSlot,
    find_published_state_address,
    state_slot_as_type,
)


comptime StateRouteMatchFn[StateType: AnyType] = def(
    StateSlot[StateType], Int
) thin -> Bool


comptime PublishedStateServeFn[StateType: AnyType] = def(
    StateSlot[StateType], IncomingRequest, mut DynamicOut
) thin -> None


def is_route_dynamic_in_state[
    StateType: AnyType, state_route_matches: StateRouteMatchFn[StateType]
](environment_key: StaticString, route_index: Int) -> Bool:

    var state_address = find_published_state_address(environment_key)
    if state_address == 0:
        return False
    var state_slot = state_slot_as_type[StateType](state_address)
    return state_route_matches(state_slot, route_index)


def serve_published_state_family[
    StateType: AnyType,
    serve_state_family: PublishedStateServeFn[StateType],
](
    environment_key: StaticString,
    request: IncomingRequest,
    mut dynamic_out: DynamicOut,
) -> Bool:

    var state_address = find_published_state_address(environment_key)
    if state_address == 0:
        return False
    var state_slot = state_slot_as_type[StateType](state_address)
    serve_state_family(state_slot, request, dynamic_out)
    return True
