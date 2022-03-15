import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kotobaten/consts/colors.dart';
import 'package:kotobaten/consts/paddings.dart';
import 'package:kotobaten/consts/routes.dart';
import 'package:kotobaten/models/slices/auth/auth_model.dart';
import 'package:kotobaten/models/slices/auth/auth_repository.dart';
import 'package:kotobaten/models/slices/auth/auth_validation_service.dart';
import 'package:kotobaten/services/daily_reminder_service.dart';
import 'package:kotobaten/views/atoms/description.dart';
import 'package:kotobaten/views/atoms/description_rich_text.dart';
import 'package:kotobaten/views/atoms/logo.dart';
import 'package:kotobaten/views/molecules/button.dart';
import 'package:kotobaten/views/molecules/windowing_app_bar.dart';
import 'package:kotobaten/views/screens/login.viewmodel.dart';
import 'package:kotobaten/views/atoms/text_span_factory.dart';

enum LoginKind { login, signup }

class LoginView extends HookConsumerWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(loginViewModelProvider);
    final authModel = ref.watch(authRepositoryProvider);
    final authValidationService = ref.read(authValidationServiceProvider);
    final dailyReminderService = ref.read(dailyReminderServiceProvider);

    final loginKind = useState(LoginKind.signup);

    if (authModel is AuthModelAuthenticated) {
      Future.microtask(() async {
        await dailyReminderService.initializeDefaults();
        await Navigator.pushNamedAndRemoveUntil(
            context, homeRoute, (route) => false);
      });
    }

    final descriptionStyle = TextStyle(color: descriptionColor);

    const inputConstraints = BoxConstraints(maxWidth: 400);
    return Scaffold(
      appBar: const WindowingAppBar(),
      body: Padding(
          padding: horizontalPadding(PaddingType.xLarge),
          child: Form(
              key: viewModel.form,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                      padding: bottomPadding(PaddingType.xxLarge),
                      child: const Logo()),
                  Padding(
                      padding: bottomPadding(PaddingType.xLarge),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Description(viewModel
                              .getSwitchKindDescription(loginKind.value)),
                          TextButton(
                            child: Text(viewModel
                                .getSwitchKindButtonLabel(loginKind.value)),
                            onPressed: () => loginKind.value =
                                loginKind.value == LoginKind.login
                                    ? LoginKind.signup
                                    : LoginKind.login,
                          )
                        ],
                      )),
                  ConstrainedBox(
                      constraints: inputConstraints,
                      child: TextFormField(
                        controller: viewModel.email,
                        validator: authValidationService.validateEmail,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      )),
                  ConstrainedBox(
                      constraints: inputConstraints,
                      child: TextFormField(
                        controller: viewModel.password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        validator: authValidationService.validatePassword,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                      )),
                  Padding(
                      padding: topPadding(PaddingType.xxLarge),
                      child: Button(
                        viewModel.getPrimaryButtonDescription(
                            loginKind.value, authModel),
                        () async {
                          final result =
                              await viewModel.authenticate(loginKind.value);
                          if (result is AuthModelAuthenticationError) {
                            onLoginError(context)(result.message);
                          }
                        },
                        type: ButtonType.primary,
                        size: ButtonSize.big,
                        icon: Icons.login,
                      )),
                  if (loginKind.value == LoginKind.signup)
                    Padding(
                        padding: topPadding(PaddingType.large),
                        child: DescriptionRichText([
                          TextSpan(
                              text:
                                  'By clicking Sign up, you\'re agreeing to the ',
                              style: descriptionStyle),
                          TextSpanFactory.link('Terms of Service',
                              Uri.https('kotobaten.app', 'terms'), context,
                              color: descriptionColor),
                          TextSpan(text: ', ', style: descriptionStyle),
                          TextSpanFactory.link('Privacy Policy',
                              Uri.https('kotobaten.app', 'privacy'), context,
                              color: descriptionColor),
                          TextSpan(text: ', and ', style: descriptionStyle),
                          TextSpanFactory.link('Cookie Policy',
                              Uri.https('kotobaten.app', 'cookies'), context,
                              color: descriptionColor)
                        ], textAlign: TextAlign.center))
                ],
              ))),
    );
  }

  onLoginError(BuildContext context) =>
      (String error) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
}
