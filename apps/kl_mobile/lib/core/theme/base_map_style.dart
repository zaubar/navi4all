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

import 'package:flutter/material.dart';
import 'package:navi4all/l10n/app_localizations.dart';

enum BaseMapStyle { light, dark, satellite }

String getBaseMapStyleTitle(BuildContext context, BaseMapStyle baseMapStyle) {
  switch (baseMapStyle) {
    case BaseMapStyle.light:
      return AppLocalizations.of(context)!.homeBaseMapStyleTitleLight;
    case BaseMapStyle.dark:
      return AppLocalizations.of(context)!.homeBaseMapStyleTitleDark;
    case BaseMapStyle.satellite:
      return AppLocalizations.of(context)!.homeBaseMapStyleTitleSatellite;
  }
}
