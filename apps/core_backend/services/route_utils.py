# Navi4All
# Copyright (C) Navi4All contributors
# Maintainer: Plan4Better GmbH
#
# SPDX-License-Identifier: AGPL-3.0-only

"""Bearing computation and turn direction utilities.

Normalises raw bearing values to [0, 360) and derives the correct
RelativeDirection from the angle between consecutive route-segment
bearings, fixing left/right confusion that can arise when relying
solely on the routing engine's own maneuver-type classification.
"""

import math
from schemas.routing import RelativeDirection


def normalize(bearing: float) -> float:
    """Wrap *bearing* to the range [0, 360)."""
    return bearing % 360


def compute(coordinates: list[tuple[float, float]]) -> float:
    """Forward bearing (degrees clockwise from true north) of a polyline
    segment approximated by its first two coordinates.

    Returns 0 for degenerate segments (< 1 coordinate).
    """
    if len(coordinates) < 2:
        return 0.0
    lat1, lon1 = coordinates[0]
    lat2, lon2 = coordinates[-1]
    delta_lon = math.radians(lon2 - lon1)
    lat1_r = math.radians(lat1)
    lat2_r = math.radians(lat2)

    x = math.sin(delta_lon) * math.cos(lat2_r)
    y = math.cos(lat1_r) * math.sin(lat2_r) - math.sin(lat1_r) * math.cos(lat2_r) * math.cos(delta_lon)

    bearing = math.degrees(math.atan2(x, y))
    return normalize(bearing)


def turn_direction(prev_bearing: float, next_bearing: float) -> RelativeDirection:
    """Map the angle between two consecutive route-segment bearings to a
    RelativeDirection.

    Angles are measured in degrees; positive = right turn,
    negative = left turn.
        angle < -135  → hard_left
        -135 ≤ angle < -45 → left
        -45  ≤ angle < -20 → slightly_left
        -20  ≤ angle ≤ 20  → continue_    (within 20° is "straight")
         20  < angle ≤ 45  → slightly_right
         45  < angle ≤ 135 → right
        angle > 135  → hard_right
    """
    delta = normalize(next_bearing - prev_bearing)

    # Treat values > 180 as a negative (left) turn.
    if delta > 180:
        delta -= 360

    if delta < -135:
        return RelativeDirection.hard_left
    if delta < -45:
        return RelativeDirection.left
    if delta < -20:
        return RelativeDirection.slightly_left
    if delta <= 20:
        return RelativeDirection.continue_
    if delta <= 45:
        return RelativeDirection.slightly_right
    if delta <= 135:
        return RelativeDirection.right
    return RelativeDirection.hard_right
