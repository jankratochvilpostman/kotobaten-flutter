import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kotobaten/consts/paddings.dart';
import 'package:kotobaten/consts/shapes.dart';
import 'package:kotobaten/models/slices/cards/card.dart' as card_entity;
import 'package:kotobaten/models/slices/cards/card_type.dart';
import 'package:kotobaten/models/slices/cards/cards_service.dart';
import 'package:kotobaten/services/navigation_service.dart';
import 'package:kotobaten/views/atoms/description_rich_text.dart';
import 'package:kotobaten/views/atoms/heading.dart';
import 'package:kotobaten/views/molecules/button.dart';
import 'package:kotobaten/views/molecules/button_async.dart';
import 'package:kotobaten/views/organisms/word_add.dart';

const minimumCardHeight = 80.0;

class WordCard extends ConsumerWidget {
  final card_entity.CardInitialized card;

  const WordCard(this.card, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardService = ref.read(cardsServiceProvider);
    final navigationService = ref.read(navigationServiceProvider);

    final furigana =
        (card.kanji?.isNotEmpty ?? false) && (card.kana?.isNotEmpty ?? false)
            ? card.kana
            : null;
    final primaryJapanese =
        (card.kanji?.isNotEmpty ?? false) ? card.kanji : card.kana;

    return Card(
      child: Padding(
          padding: allPadding(PaddingType.standard),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minimumCardHeight),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Padding(
                            padding: leftPadding(PaddingType.standard),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (card.type == CardType.word &&
                                    furigana != null)
                                  DescriptionRichText([
                                    TextSpan(
                                        text: furigana,
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12))
                                  ]),
                                if (card.type == CardType.grammar)
                                  const DescriptionRichText([
                                    TextSpan(
                                        text: "(grammar)",
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12))
                                  ]),
                                Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        0, 0, 0, furigana != null ? 22 : 4),
                                    child: Text(
                                      card.type == CardType.word
                                          ? primaryJapanese ?? ''
                                          : card.sense,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w400),
                                    )),
                              ],
                            ))),
                    Expanded(
                        child: Heading(
                      card.type == CardType.word
                          ? card.sense
                          : card.kanji ?? '',
                      HeadingStyle.h3,
                      textAlign: TextAlign.left,
                    )),
                    Padding(
                        padding: leftPadding(PaddingType.standard),
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => showModalBottomSheet(
                              shape: defaultBottomSheetShape,
                              context: context,
                              builder: (_) => SizedBox(
                                  height: 120,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading:
                                            const Icon(Icons.edit_outlined),
                                        title: const Text('Edit word'),
                                        onTap: () => showWordAddBottomSheet(
                                            context, (word) async {
                                          final result = await cardService
                                              .editCard(word as card_entity
                                                  .CardInitialized);
                                          navigationService.goBack(context);
                                          navigationService.goBack(context);

                                          return result;
                                        }, existingWord: card),
                                      ),
                                      ListTile(
                                        iconColor: Colors.red,
                                        textColor: Colors.red,
                                        leading:
                                            const Icon(Icons.delete_outline),
                                        title: const Text('Delete word'),
                                        onTap: () => showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                                  title:
                                                      const Text('Delete word'),
                                                  content: Text(
                                                      'Are you sure you want to delete "${card.sense}" from your collection?'),
                                                  actions: [
                                                    ButtonAsync(
                                                      'Yes',
                                                      () async {
                                                        await cardService
                                                            .deleteCard(card);
                                                        navigationService
                                                            .goBack(context);
                                                        navigationService
                                                            .goBack(context);
                                                      },
                                                      icon: Icons.check,
                                                    ),
                                                    Button(
                                                      'No',
                                                      () => navigationService
                                                          .goBack(context),
                                                      icon:
                                                          Icons.cancel_outlined,
                                                      type:
                                                          ButtonType.secondary,
                                                    ),
                                                  ],
                                                )),
                                      )
                                    ],
                                  ))),
                          child: const Icon(
                            Icons.more_horiz,
                            color: Colors.black38,
                            size: 14,
                          ),
                        ))
                  ],
                )),
            if (card.note?.isNotEmpty ?? false)
              Padding(
                  padding: EdgeInsets.fromLTRB(getPadding(PaddingType.standard),
                      getPadding(PaddingType.standard), 0, 0),
                  child: Row(children: [
                    Padding(
                        padding: topPadding(PaddingType.xSmall),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 12,
                          color: Colors.black45,
                        )),
                    Expanded(
                        child: Padding(
                            padding: leftPadding(PaddingType.small),
                            child: Text(card.note ?? '',
                                softWrap: true,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12))))
                  ])),
          ])),
    );
  }
}
