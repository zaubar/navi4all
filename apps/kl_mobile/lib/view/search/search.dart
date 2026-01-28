import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:navi4all/controllers/canvas_controller.dart';
import 'package:navi4all/controllers/place_controller.dart';
import 'package:navi4all/core/theme/icons.dart';
import 'package:navi4all/view/canvas/canvas_screen.dart';
import 'package:navi4all/view/common/accessible_button.dart';
import 'package:provider/provider.dart';
import 'package:navi4all/controllers/autocomplete_controller.dart';
import 'package:navi4all/l10n/app_localizations.dart';
import 'package:navi4all/schemas/routing/place.dart';

class SearchScreen extends StatefulWidget {
  final bool isSecondarySearch;
  final bool isOriginPlaceSearch;
  final bool altMode;

  const SearchScreen({
    super.key,
    this.isSecondarySearch = false,
    this.isOriginPlaceSearch = false,
    this.altMode = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    _focusNode.requestFocus();
    Provider.of<AutocompleteController>(context, listen: false).reset();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSuggestionTap(Place place) async {
    // Close keyboard
    _focusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 250));

    // Navigate away from search screen
    if (widget.isSecondarySearch) {
      Navigator.of(context).pop(place);
    } else {
      Provider.of<CanvasController>(
        context,
        listen: false,
      ).setState(CanvasControllerState.place);
      Provider.of<PlaceController>(context, listen: false).setPlace(place);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CanvasScreen(altMode: widget.altMode),
        ),
      );
    }

    // Write selected place to recent searches
    await Future.delayed(const Duration(milliseconds: 250));
    await Provider.of<AutocompleteController>(
      context,
      listen: false,
    ).addRecentSearch(place);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Consumer<AutocompleteController>(
          builder: (context, autocompleteController, _) => Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(32),
                    topRight: const Radius.circular(32),
                    bottomLeft: autocompleteController.searchResults.isNotEmpty
                        ? const Radius.circular(0)
                        : const Radius.circular(32),
                    bottomRight: autocompleteController.searchResults.isNotEmpty
                        ? const Radius.circular(0)
                        : const Radius.circular(32),
                  ),
                  border: autocompleteController.searchResults.isNotEmpty
                      ? Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Semantics(
                      sortKey: OrdinalSortKey(1),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: AppLocalizations.of(
                            context,
                          )!.commonBackButtonSemantic,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        label: autocompleteController.searchQuery.isEmpty
                            ? widget.isOriginPlaceSearch
                                  ? AppLocalizations.of(
                                      context,
                                    )!.searchTextFieldOriginHintSemantic
                                  : AppLocalizations.of(
                                      context,
                                    )!.searchTextFieldDestinationHintSemantic
                            : AppLocalizations.of(
                                context,
                              )!.searchScreenSearchFieldSemantic(
                                autocompleteController.searchQuery,
                              ),
                        excludeSemantics: true,
                        sortKey: OrdinalSortKey(0),
                        focused: true,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.searchTextFieldHint,
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onChanged: (value) =>
                              Provider.of<AutocompleteController>(
                                context,
                                listen: false,
                              ).updateSearchQuery(value.trim()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              autocompleteController.searchResults.isNotEmpty
                  ? const SizedBox.shrink()
                  : const SizedBox(height: 32),
              autocompleteController.searchQuery.isEmpty &&
                      autocompleteController.recentSearches.isNotEmpty
                  ? Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final place =
                                autocompleteController.recentSearches[index];
                            return _SearchSuggestion(
                              place: place,
                              isRecentSearch: true,
                              onTap: () => _onSuggestionTap(place),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            );
                          },
                          itemCount:
                              autocompleteController.recentSearches.length,
                        ),
                      ),
                    )
                  : autocompleteController.searchQuery.isNotEmpty &&
                        autocompleteController.searchResults.isNotEmpty
                  ? Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final place =
                                autocompleteController.searchResults[index];
                            return _SearchSuggestion(
                              place: place,
                              onTap: () => _onSuggestionTap(place),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            );
                          },
                          itemCount:
                              autocompleteController.searchResults.length,
                        ),
                      ),
                    )
                  : Semantics(
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 96,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              autocompleteController.searchQuery.isEmpty
                                  ? AppLocalizations.of(
                                      context,
                                    )!.searchScreenPrompt
                                  : AppLocalizations.of(
                                      context,
                                    )!.searchScreenErrorNoSuggestions,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              const Spacer(),
              widget.altMode
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: AccessibleButton(
                        label: AppLocalizations.of(
                          context,
                        )!.commonHomeScreenButton,
                        style: AccessibleButtonStyle.pink,
                        onTap: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                      ),
                    )
                  : SizedBox.shrink(),
              widget.altMode ? SizedBox(height: 8) : SizedBox.shrink(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SearchSuggestion extends StatelessWidget {
  final Place place;
  final bool isRecentSearch;
  final Function onTap;
  const _SearchSuggestion({
    required this.place,
    this.isRecentSearch = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onTap(),
        child: Semantics(
          label: !isRecentSearch
              ? AppLocalizations.of(
                  context,
                )!.searchResultSemantic(place.name, place.locality ?? '')
              : AppLocalizations.of(
                  context,
                )!.searchScreenRecentSearchItemSemantic(place.name),
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                (place.type == PlaceType.parkingSpot ||
                        place.type == PlaceType.parkingSite)
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                      )
                    : Icon(
                        isRecentSearch
                            ? Icons.history_rounded
                            : PlaceTypeIcons.get(place.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        place.locality ?? place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                place.isFavorite != null && place.isFavorite!
                    ? const SizedBox(width: 12)
                    : const SizedBox.shrink(),
                place.isFavorite != null && place.isFavorite!
                    ? Icon(
                        Icons.star,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
