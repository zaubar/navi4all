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

class SheetButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool shrinkWrap;

  const SheetButton({
    super.key,
    this.label,
    required this.onTap,
    this.semanticLabel,
    this.icon,
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      button: true,
      child: Material(
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(32)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
              children: [
                icon != null
                    ? Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      )
                    : const SizedBox.shrink(),
                icon != null && label != null
                    ? const SizedBox(width: 8)
                    : const SizedBox.shrink(),
                label != null
                    ? Flexible(
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum SheetButtonStyle { white, pink, red }
