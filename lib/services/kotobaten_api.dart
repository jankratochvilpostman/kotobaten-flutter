import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:kotobaten/consts/http.dart';
import 'package:kotobaten/models/app_configuration.dart';
import 'package:kotobaten/models/impression.dart';
import 'package:kotobaten/models/slices/auth/auth_model.dart';
import 'package:kotobaten/models/slices/auth/auth_repository.dart';
import 'package:kotobaten/models/slices/cards/card.dart';
import 'package:kotobaten/models/slices/user/user.dart';
import 'package:kotobaten/models/slices/user/user_goals.dart';
import 'package:kotobaten/models/slices/user/user_statistics.dart';
import 'package:kotobaten/services/app_configuration.dart';
import 'package:kotobaten/services/kotobaten_client.dart';
import 'package:kotobaten/services/serialization/requests/impressions_request.dart';
import 'package:kotobaten/services/serialization/responses/impressions_response.dart';
import 'package:kotobaten/services/serialization/responses/practice_response.dart';
import 'package:tuple/tuple.dart';
import 'package:mockito/annotations.dart';

final kotobatenApiServiceProvider = Provider((ref) => KotobatenApiService(
    ref.watch(authRepositoryProvider.notifier),
    ref.watch(appConfigurationProvider),
    ref.watch(kotobatenClientProvider)));

class KotobatenApiService {
  // Not using AuthService as it'd cause a cyclical dependency.
  final AuthRepository authRepository;
  final AppConfiguration _appConfiguration;
  final KotobatenClient _kotobatenClient;

  KotobatenApiService(
      this.authRepository, this._appConfiguration, this._kotobatenClient);

  Future<Tuple2<bool, String>> login(String username, String password) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'auth/login');

    try {
      final loginResponse = await _kotobatenClient.post(url, body: {
        'grant_type': 'password',
        'username': username,
        'password': password
      });

      final body = utf8.decode(loginResponse.bodyBytes);

      if (loginResponse.statusCode != 200) {
        return Tuple2(
            false,
            body.isNotEmpty
                ? body
                : loginResponse.reasonPhrase ??
                    loginResponse.statusCode.toString());
      }

      final token = jsonDecode(body)['access_token'] as String;
      return Tuple2(true, token);
    } on ClientException catch (e) {
      return Tuple2(false, e.message);
    }
  }

  Future<UserInitialized> getUser(
          {bool updateRetentionBackstop = false}) async =>
      UserInitialized.fromJson(await _getAuthenticated('user',
          params: {'overrideBackstop': updateRetentionBackstop.toString()}));

  Future<List<Impression>> getImpressions() async => PracticeResponse.fromJson(
          await _getAuthenticated('practice', params: {'count': '15'}))
      .impressions;

  Future<UserStatistics> postImpression(
      Impression impression, bool success) async {
    final requestBody = ImpressionsRequest.initialized(
        impression.impressionType, impression.card.id, success, DateTime.now());

    final responseBody = await _postJson('impressions', requestBody.toJson());

    final stats = ImpressionsResponse.fromJson(responseBody).userStats;
    return stats;
  }

  Future<CardInitialized> postCard(Card card) async {
    final responseBody = await _postJson('cards', card.toJson());
    final createdCard = CardInitialized.fromJson(responseBody);
    return createdCard;
  }

  Future<bool> deleteCard(int cardId) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'cards/$cardId');

    var headers = await _getTokenHeadersOrThrow();
    headers.addEntries([contentTypeJsonHeader]);

    await _kotobatenClient.delete(url, headers: headers);

    return true;
  }

  Future<UserGoals> updateGoals(UserGoals goals) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'goals', {
      'discoverDaily': goals.discoverDaily.toString(),
      'discoverWeekly': goals.discoverWeekly.toString(),
      'discoverMonthly': goals.discoverMonthly.toString()
    });

    var headers = await _getTokenHeadersOrThrow();
    headers.addEntries([contentTypeJsonHeader]);

    final response = await _kotobatenClient.post(url, headers: headers);
    final body = utf8.decode(response.bodyBytes);
    return UserGoals.fromJson(jsonDecode(body));
  }

  Future<List<CardInitialized>> getCards(int page, int pageSize) async {
    final responseJson = await _getAuthenticated('cards',
        params: {'pageSize': pageSize.toString(), 'page': page.toString()});
    final result = List<CardInitialized>.from(
        responseJson.map((model) => CardInitialized.fromJson(model)));

    return result;
  }

  Future<dynamic> _getAuthenticated(String relativePath,
      {Map<String, dynamic>? params}) async {
    final url = _getUrl(_appConfiguration.apiRoot, relativePath, params);

    final response = await _kotobatenClient.get(url,
        headers: await _getTokenHeadersOrThrow());

    final body = utf8.decode(response.bodyBytes);
    return jsonDecode(body);
  }

  Future<Map<String, String>> _getTokenHeadersOrThrow() async {
    final authModel = authRepository.current;
    final token = authModel is AuthModelAuthenticated ? authModel.token : null;

    if (token == null) {
      throw Exception('User not authenticated, cannot call getUser');
    }
    return {'Authorization': 'Bearer $token'};
  }

  _getUrl(String authority, String unencodedPath,
          [Map<String, dynamic>? queryParameters]) =>
      _appConfiguration.isApiHttps
          ? Uri.https(authority, unencodedPath, queryParameters)
          : Uri.http(authority, unencodedPath, queryParameters);

  _postJson(String relativePath, Map<String, dynamic> requestBody) async {
    final url = _getUrl(_appConfiguration.apiRoot, relativePath);

    var headers = await _getTokenHeadersOrThrow();
    headers.addEntries([contentTypeJsonHeader]);

    final response = await _kotobatenClient.post(url,
        body: json.encode(requestBody), headers: headers);
    final body = utf8.decode(response.bodyBytes);
    return jsonDecode(body);
  }
}

@GenerateMocks([KotobatenApiService])
void main() {}
