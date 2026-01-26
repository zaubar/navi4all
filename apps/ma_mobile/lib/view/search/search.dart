import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:smartroots/controllers/autocomplete_controller.dart';
import 'package:smartroots/core/theme/icons.dart';
import 'package:smartroots/l10n/app_localizations.dart';
import 'package:smartroots/core/theme/colors.dart';
import 'package:smartroots/view/parking_location/parking_location.dart';
import 'package:smartroots/view/place/place.dart';
import 'package:smartroots/schemas/routing/place.dart';

class SearchScreen extends StatefulWidget {
  final bool isSecondarySearch;
  final bool isOriginPlaceSearch;

  const SearchScreen({
    super.key,
    this.isSecondarySearch = false,
    this.isOriginPlaceSearch = false,
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
      if (place.type == PlaceType.parkingSpot ||
          place.type == PlaceType.parkingSite) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ParkingLocationScreen(parkingLocation: place),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PlaceScreen(place: place)),
        );
      }
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
                      ? const Border(
                          bottom: BorderSide(
                            color: SmartRootsColors.maBlue,
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
                          color: Theme.of(
                            context,
                          ).textTheme.displayMedium!.color,
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
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          style: const TextStyle(fontSize: 16),
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
                            return const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: SmartRootsColors.maBlue,
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
                            return const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: SmartRootsColors.maBlue,
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
                            color: SmartRootsColors.maBlue,
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
                                color: SmartRootsColors.maBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              const Spacer(),
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
                          color: SmartRootsColors.maBlue,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 16,
                              color: SmartRootsColors.maBlueLight,
                            ),
                          ],
                        ),
                      )
                    : Icon(
                        isRecentSearch
                            ? Icons.history_rounded
                            : PlaceTypeIcons.get(place.type),
                        color: SmartRootsColors.maBlue,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        place.locality ?? place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                place.isFavorite != null && place.isFavorite!
                    ? const SizedBox(width: 12)
                    : const SizedBox.shrink(),
                place.isFavorite != null && place.isFavorite!
                    ? Icon(Icons.star, color: SmartRootsColors.maBlue)
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
