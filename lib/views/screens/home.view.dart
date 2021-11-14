import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kotobaten/consts/paddings.dart';
import 'package:kotobaten/consts/routes.dart';
import 'package:kotobaten/models/user/user.dart';
import 'package:kotobaten/services/providers.dart';
import 'package:kotobaten/views/atoms/description_rich_text.dart';
import 'package:kotobaten/views/atoms/heading.dart';
import 'package:kotobaten/views/molecules/headed.dart';
import 'package:kotobaten/views/screens/home.model.dart';
import 'package:kotobaten/views/screens/home.viewmodel.dart';

final _viewModelProvider = StateNotifierProvider<HomeViewModel, HomeModel>(
    (ref) => HomeViewModel(
        ref.watch(kotobatenApiServiceProvider),
        ref.watch(authenticationServiceProvider),
        ref.watch(userRepositoryProvider.notifier)));

class HomeView extends HookConsumerWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(_viewModelProvider.notifier);
    final model = ref.watch(_viewModelProvider);
    final user = ref.watch(userRepositoryProvider);

    if (model is Initial) {
      Future.microtask(() => viewModel.initialize());
    }

    if (model is RequiresLogin) {
      Future.microtask(() => viewModel.reset());
      Future.microtask(() => Navigator.pushNamedAndRemoveUntil(
          context, loginRoute, (route) => false));
    }

    if (model is Initialized && user is InitializedUser) {
      return Scaffold(
          body: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: bottomPadding(PaddingType.largePlus),
              child: Headed(
                  Column(children: [
                    DescriptionRichText(
                      [
                        const TextSpan(text: 'You have '),
                        TextSpan(
                            text:
                                '${user.stats.leftToPractice > 0 ? user.stats.leftToPractice.toString() : 'no'} words',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: ' to refresh.')
                      ],
                    ),
                    DescriptionRichText(
                      [
                        const TextSpan(text: 'You learned '),
                        TextSpan(
                            text:
                                '${user.stats.discoveredWeek > 0 ? user.stats.discoveredWeek.toString() : 'no'} words',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: ' this week.')
                      ],
                    ),
                    Padding(
                        padding: topPadding(PaddingType.large),
                        child: ElevatedButton(
                            onPressed: () => {},
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bolt_outlined),
                                Text('Learn')
                              ],
                            )))
                  ]),
                  'Learn',
                  HeadingStyle.h1)),
          Headed(
              DescriptionRichText(
                [
                  const TextSpan(text: 'You added '),
                  TextSpan(
                      text:
                          '${user.stats.discoveredWeek > 0 ? user.stats.discoveredWeek.toString() : 'no'} words',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' this week.')
                ],
              ),
              'Collect',
              HeadingStyle.h1)
        ],
      )));
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
