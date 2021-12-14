import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kotobaten/models/user/user.dart';

import 'package:mockito/annotations.dart';

class UserRepository extends StateNotifier<User> {
  UserRepository() : super(User.initial());

  Future set(User user) {
    state = user;
    return Future.microtask(() => true);
  }

  User get() => state;
}

@GenerateMocks([UserRepository])
void main() {}