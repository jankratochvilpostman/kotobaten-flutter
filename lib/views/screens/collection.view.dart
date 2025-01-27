import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kotobaten/consts/paddings.dart';
import 'package:kotobaten/extensions/datetime.dart';
import 'package:kotobaten/extensions/string.dart';
import 'package:kotobaten/models/slices/cards/card.dart';
import 'package:kotobaten/models/slices/cards/cards_model.dart';
import 'package:kotobaten/models/slices/cards/cards_repository.dart';
import 'package:kotobaten/models/slices/cards/cards_service.dart';
import 'package:kotobaten/views/atoms/empty.dart';
import 'package:kotobaten/views/atoms/heading.dart';
import 'package:kotobaten/views/molecules/word_card.dart';
import 'package:kotobaten/views/organisms/loading.dart';
import 'package:kotobaten/views/organisms/word_add.dart';
import 'package:kotobaten/views/templates/scaffold_default.view.dart';

class CollectionView extends HookConsumerWidget {
  const CollectionView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsService = ref.watch(cardsServiceProvider);
    final cardsModel = ref.watch(cardsRepositoryProvider);

    if (cardsModel is CardsModelInitial) {
      unawaited(Future.microtask(() => cardsService.initialize()));
    }

    if (cardsModel is CardsModelInitialized) {
      final groups = groupBy<CardInitialized, DateTime>(cardsModel.cards,
          (x) => DateTime(x.created.year, x.created.month, x.created.day));

      final cardsWithHeadings = groups.entries.fold<List<dynamic>>(
        <dynamic>[],
        (previous, current) => [...previous, current.key, ...current.value],
      );

      return ScaffoldDefault(
        ListView.builder(
            itemCount: cardsWithHeadings.length + 1,
            itemBuilder: (context, index) {
              if (index == cardsWithHeadings.length) {
                if (!cardsModel.loadingNextPage && cardsModel.hasMoreCards) {
                  Future.microtask(() => cardsService.loadMoreCards());
                }

                if (cardsModel.loadingNextPage) {
                  return Center(
                    child: Padding(
                        padding: allPadding(PaddingType.standard),
                        child: const CircularProgressIndicator()),
                  );
                }
                return const Empty();
              }

              final current = cardsWithHeadings[index];

              if (current is CardInitialized) {
                return WordCard(current);
              }

              if (current is DateTime) {
                return Center(
                    child: Padding(
                        padding: allPadding(PaddingType.xLarge),
                        child: Heading(
                            current
                                .getRelativeToNowString(DateTime.now())
                                .capitalize(),
                            HeadingStyle.h2)));
              }

              throw ErrorDescription("Invalid object type in collection list");
            }),
        floatingActionButton: FloatingActionButton(
            tooltip: 'Add word',
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () => showWordAddBottomSheet(context, (card) async {
                  if (card is CardNew) {
                    return await cardsService.createCard(card);
                  } else if (card is CardInitialized) {
                    return await cardsService.editCard(card);
                  }

                  throw UnsupportedError(
                      'Card needs to be either new or initialized');
                }),
            child: const Icon(Icons.move_to_inbox_outlined)),
      );
    }

    return const Loading();
  }
}
