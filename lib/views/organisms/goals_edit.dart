import 'package:flutter/material.dart';
import 'package:kotobaten/consts/paddings.dart';
import 'package:kotobaten/models/slices/user/user_goals.dart';
import 'package:kotobaten/views/molecules/button.dart';

showGoalsEditDialog(
        BuildContext context,
        Future<UserGoals> Function(UserGoals goals) onSubmit,
        UserGoals currentGoals) =>
    showModalBottomSheet(
        context: context,
        builder: (x) => Padding(
            padding: MediaQuery.of(x).viewInsets,
            child: GoalsEditDialog(
              (card) async {
                await onSubmit(card);

                Navigator.pop(x);
                ScaffoldMessenger.of(x).showSnackBar(
                    const SnackBar(content: Text('Goals edited.')));
              },
              currentGoals,
            )));

class GoalsEditDialog extends StatefulWidget {
  final void Function(UserGoals goals) _onSubmit;
  final UserGoals currentGoals;

  const GoalsEditDialog(this._onSubmit, this.currentGoals, {Key? key})
      : super(key: key);

  @override
  _GoalsEditDialogState createState() => _GoalsEditDialogState();
}

class _GoalsEditDialogState extends State<GoalsEditDialog> {
  final _formKey = GlobalKey<FormState>();

  final _goalDayController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _goalDayController.text = widget.currentGoals.discoverDaily.toString();
  }

  String? validateGoal(String? value) {
    if (value == null || value.isEmpty || int.tryParse(value) == null) {
      return 'Enter a valid goal.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    onEditComplete() {
      if (_formKey.currentState!.validate()) {
        final dailyGoal = int.parse(_goalDayController.text);
        final weeklyGoal = dailyGoal * 7;
        final monthlyGoal = weeklyGoal * 4;
        widget._onSubmit(UserGoals(weeklyGoal, monthlyGoal, dailyGoal));
      }
    }

    return Material(
        child: Form(
            key: _formKey,
            child: Padding(
              padding: allPadding(PaddingType.large),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _goalDayController,
                      validator: validateGoal,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Daily goal', suffixText: 'new words'),
                    ),
                    SizedBox(
                      height: getPadding(PaddingType.small),
                    ),
                    Align(
                        alignment: Alignment.centerRight,
                        child: Button(
                          'Save goals',
                          onEditComplete,
                          icon: Icons.edit_outlined,
                          type: ButtonType.primary,
                          size: ButtonSize.big,
                        ))
                  ]),
            )));
  }
}
