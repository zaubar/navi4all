# Navi4All
# Copyright (C) Navi4All contributors
# Maintainer: Plan4Better GmbH
#
# SPDX-License-Identifier: AGPL-3.0-only
#
# Licensed under the GNU Affero General Public License, Version 3 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.gnu.org/licenses/agpl-3.0.en.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


"""Settings boot without the retired OpenTripPlanner URLs.

The two OTP URLs used to be required fields, so a compose/helm env that no
longer sets them would have failed at import with a pydantic ValidationError
before FastAPI started. They are optional now, and the two avoid_bad_surfaces
tunables carry bounded defaults.
"""

import pytest
from pydantic import ValidationError

from core.config import Settings
from schemas.routing import RoutingEngine


def _clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OPEN_TRIP_PLANNER_URL", raising=False)
    monkeypatch.delenv("OPEN_TRIP_PLANNER_KL_URL", raising=False)
    monkeypatch.delenv("VALHALLA_AVOID_BAD_SURFACES_SMOOTH", raising=False)
    monkeypatch.delenv("VALHALLA_AVOID_BAD_SURFACES_MEDIUM", raising=False)
    monkeypatch.setenv("VALHALLA_URL", "https://valhalla.example")
    monkeypatch.setenv("GEOCODING_PROVIDER", "none")


def test_settings_boot_without_otp_urls(monkeypatch: pytest.MonkeyPatch) -> None:
    _clean_env(monkeypatch)

    settings = Settings(_env_file=None)

    assert settings.OPEN_TRIP_PLANNER_URL is None
    assert settings.OPEN_TRIP_PLANNER_KL_URL is None
    assert settings.VALHALLA_URL == "https://valhalla.example"
    # Only Valhalla is mapped; no retired engine key is present.
    assert settings.ROUTING_ENGINE_URLS == {
        RoutingEngine.valhalla: "https://valhalla.example"
    }


def test_settings_still_accept_otp_urls_when_present(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Existing compose/helm env keeps booting; the value is accepted and ignored.
    _clean_env(monkeypatch)
    monkeypatch.setenv("OPEN_TRIP_PLANNER_URL", "https://otp.example/graphql")

    settings = Settings(_env_file=None)

    assert settings.OPEN_TRIP_PLANNER_URL == "https://otp.example/graphql"
    assert settings.OPEN_TRIP_PLANNER_KL_URL is None


def test_avoid_bad_surfaces_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    _clean_env(monkeypatch)

    settings = Settings(_env_file=None)

    assert settings.VALHALLA_AVOID_BAD_SURFACES_SMOOTH == 0.4
    assert settings.VALHALLA_AVOID_BAD_SURFACES_MEDIUM == 0.15
    assert settings.VALHALLA_AVOID_VERY_ROUGH_SURFACES_SMOOTH == 1.0
    assert settings.VALHALLA_AVOID_VERY_ROUGH_SURFACES_MEDIUM == 0.4


def test_avoid_bad_surfaces_follow_env(monkeypatch: pytest.MonkeyPatch) -> None:
    _clean_env(monkeypatch)
    monkeypatch.setenv("VALHALLA_AVOID_BAD_SURFACES_SMOOTH", "0.8")
    monkeypatch.setenv("VALHALLA_AVOID_BAD_SURFACES_MEDIUM", "0.2")
    monkeypatch.setenv("VALHALLA_AVOID_VERY_ROUGH_SURFACES_SMOOTH", "0.9")
    monkeypatch.setenv("VALHALLA_AVOID_VERY_ROUGH_SURFACES_MEDIUM", "0.3")

    settings = Settings(_env_file=None)

    assert settings.VALHALLA_AVOID_BAD_SURFACES_SMOOTH == 0.8
    assert settings.VALHALLA_AVOID_BAD_SURFACES_MEDIUM == 0.2
    assert settings.VALHALLA_AVOID_VERY_ROUGH_SURFACES_SMOOTH == 0.9
    assert settings.VALHALLA_AVOID_VERY_ROUGH_SURFACES_MEDIUM == 0.3


@pytest.mark.parametrize("value", ["1.5", "-0.1"])
def test_avoid_bad_surfaces_out_of_range_is_rejected(
    monkeypatch: pytest.MonkeyPatch, value: str
) -> None:
    _clean_env(monkeypatch)
    monkeypatch.setenv("VALHALLA_AVOID_BAD_SURFACES_SMOOTH", value)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_valhalla_url_is_still_required(monkeypatch: pytest.MonkeyPatch) -> None:
    _clean_env(monkeypatch)
    monkeypatch.delenv("VALHALLA_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)
