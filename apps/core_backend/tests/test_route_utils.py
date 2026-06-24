"""Tests for route_utils bearing and turn-direction computation."""

import pytest
import math
from services.route_utils import normalize, compute, turn_direction
from schemas.routing import RelativeDirection


class TestNormalize:
    def test_returns_positive_angle(self):
        assert normalize(360) == 0
        assert normalize(450) == 90
        assert normalize(720) == 0

    def test_wraps_negative_values(self):
        assert normalize(-90) == 270
        assert normalize(-360) == 0
        assert normalize(-450) == 270

    def test_zero_stays_zero(self):
        assert normalize(0) == 0

    def test_already_in_range(self):
        assert normalize(45) == 45
        assert normalize(180) == 180
        assert normalize(359) == 359


class TestCompute:
    def test_northward(self):
        # Moving north: bearing ~0°
        bearing = compute([(50.0, 10.0), (51.0, 10.0)])
        assert bearing == pytest.approx(0.0, abs=1)

    def test_southward(self):
        # Moving south: bearing ~180°
        bearing = compute([(50.0, 10.0), (49.0, 10.0)])
        assert bearing == pytest.approx(180.0, abs=1)

    def test_eastward(self):
        # Moving east: bearing ~90°
        bearing = compute([(50.0, 10.0), (50.0, 11.0)])
        assert bearing == pytest.approx(90.0, abs=1)

    def test_westward(self):
        # Moving west: bearing ~270°
        bearing = compute([(50.0, 10.0), (50.0, 9.0)])
        assert bearing == pytest.approx(270.0, abs=1)

    def test_degenerate_single_point(self):
        assert compute([(50.0, 10.0)]) == 0.0

    def test_degenerate_empty_list(self):
        assert compute([]) == 0.0

    def test_northeast(self):
        bearing = compute([(50.0, 10.0), (51.0, 11.0)])
        # Roughly northeast = ~32°
        assert bearing == pytest.approx(32.0, abs=3)

    def test_southwest(self):
        bearing = compute([(50.0, 10.0), (49.0, 9.0)])
        # Roughly southwest = ~213°
        assert bearing == pytest.approx(213.0, abs=3)

    def test_uses_endpoints_not_midpoints(self):
        # Only first and last matter
        bearing = compute([(50.0, 10.0), (50.5, 10.5), (51.0, 11.0)])
        assert bearing == pytest.approx(32.0, abs=3)


class TestTurnDirection:
    def test_straight(self):
        assert turn_direction(0, 0) == RelativeDirection.continue_
        assert turn_direction(90, 95) == RelativeDirection.continue_
        assert turn_direction(180, 175) == RelativeDirection.continue_

    def test_slight_right(self):
        assert turn_direction(0, 25) == RelativeDirection.slightly_right

    def test_right(self):
        assert turn_direction(0, 60) == RelativeDirection.right
        assert turn_direction(0, 130) == RelativeDirection.right

    def test_hard_right(self):
        assert turn_direction(0, 140) == RelativeDirection.hard_right
        assert turn_direction(0, 170) == RelativeDirection.hard_right

    def test_slight_left(self):
        # 350° is a 10° left turn → continue (within 20°)
        assert turn_direction(0, 355) == RelativeDirection.continue_
        # 340° is a 20° left turn → continue (within 20°)
        assert turn_direction(0, 340) == RelativeDirection.continue_
        # 330° is a 30° left turn → slightly_left
        assert turn_direction(0, 330) == RelativeDirection.slightly_left

    def test_left(self):
        assert turn_direction(0, 310) == RelativeDirection.left
        assert turn_direction(0, 250) == RelativeDirection.left

    def test_hard_left(self):
        assert turn_direction(0, 220) == RelativeDirection.hard_left

    def test_wraps_nicely(self):
        # 350° → 10° is a 20° right turn → continue
        assert turn_direction(350, 10) == RelativeDirection.continue_
        # 350° → 30° is a 40° right turn → slightly_right
        assert turn_direction(350, 30) == RelativeDirection.slightly_right
        # 10° → 350° is a 20° left turn → continue
        assert turn_direction(10, 350) == RelativeDirection.continue_

    def test_uturn_is_hard(self):
        # ~180° delta → hard_right (clockwise)
        assert turn_direction(0, 180) == RelativeDirection.hard_right
        # Also works the other way
        assert turn_direction(180, 0) == RelativeDirection.hard_right
