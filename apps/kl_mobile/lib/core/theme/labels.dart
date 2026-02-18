// Navi4All
// Copyright (C) Navi4All contributors
// Maintainer: Plan4Better GmbH
//
// SPDX-License-Identifier: AGPL-3.0-only
//
// Licensed under the GNU Affero General Public License, Version 3 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.gnu.org/licenses/agpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/widgets.dart';
import 'package:navi4all/core/theme/profile_mode.dart';
import 'package:navi4all/l10n/app_localizations.dart';

class Navi4AllLabels {
  static const String appName = 'Navi4All';

  static getRoutingProfileLabel(BuildContext context, RoutingProfile profile) {
    switch (profile) {
      case RoutingProfile.standard:
        return AppLocalizations.of(context)!.routingProfileLabelStandard;
      case RoutingProfile.visionImpairment:
        return AppLocalizations.of(
          context,
        )!.routingProfileLabelVisionImpairment;
      case RoutingProfile.wheelchair:
        return AppLocalizations.of(context)!.routingProfileLabelWheelchair;
      case RoutingProfile.rollator:
        return AppLocalizations.of(context)!.routingProfileLabelRollator;
      case RoutingProfile.slightWalkingDisability:
        return AppLocalizations.of(
          context,
        )!.routingProfileLabelSlightWalkingDisability;
      case RoutingProfile.moderateWalkingDisability:
        return AppLocalizations.of(
          context,
        )!.routingProfileLabelModerateWalkingDisability;
      case RoutingProfile.severeWalkingDisability:
        return AppLocalizations.of(
          context,
        )!.routingProfileLabelSevereWalkingDisability;
      case RoutingProfile.stroller:
        return AppLocalizations.of(context)!.routingProfileLabelStroller;
    }
  }
}
