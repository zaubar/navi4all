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

class AccessibleSelector extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AccessibleSelector({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 288.0,
        decoration: BoxDecoration(
          color: selected ? Navi4AllColors.klWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(Navi4AllGeometry.radiusMedium),
          border: Border.all(
            color: Colors.white,
            width: Navi4AllGeometry.thickness,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Navi4AllGeometry.fontSizeSmall,
            color: selected ? Navi4AllColors.klRed : Navi4AllColors.klWhite,
            // Optionally, you can change color if selected
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
