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
import 'package:navi4all/core/theme/colors.dart';
import 'package:navi4all/core/theme/geometry.dart';

class AccessibleButton extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final AccessibleButtonStyle style;
  final VoidCallback? onTap;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      excludeSemantics: true,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: style == AccessibleButtonStyle.white
              ? Navi4AllColors.klWhite
              : style == AccessibleButtonStyle.pink
              ? Theme.of(context).colorScheme.secondary
              : Navi4AllColors.klRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Navi4AllGeometry.radiusLarge),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        ),
        child: SizedBox(
          width: 256.0,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Navi4AllGeometry.fontSizeMedium,
              color:
                  (style == AccessibleButtonStyle.white) |
                      (style == AccessibleButtonStyle.pink)
                  ? Navi4AllColors.klRed
                  : Navi4AllColors.klWhite,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

enum AccessibleButtonStyle { white, pink, red }
