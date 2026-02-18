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

class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasNotification;
  final String? semanticLabel;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.hasNotification = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    button: true,
    child: Stack(
      children: [
        Ink(
          decoration: ShapeDecoration(
            shape: CircleBorder(),
            color: Theme.of(context).colorScheme.tertiary,
          ),
          child: IconButton(
            icon: Stack(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
              ],
            ),
            onPressed: onTap,
            tooltip: semanticLabel,
          ),
        ),
        hasNotification
            ? Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 8, left: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).textTheme.displayMedium?.color,
                ),
              )
            : SizedBox.shrink(),
      ],
    ),
  );
}
