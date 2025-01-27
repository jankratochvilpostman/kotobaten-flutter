import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:kotobaten/consts/http.dart';
import 'package:kotobaten/extensions/auth_model.dart';
import 'package:kotobaten/models/app_configuration.dart';
import 'package:kotobaten/models/search_result.dart';
import 'package:kotobaten/models/slices/auth/auth_model.dart';
import 'package:kotobaten/models/slices/auth/auth_repository.dart';
import 'package:kotobaten/models/slices/auth/auth_result.dart';
import 'package:kotobaten/models/slices/cards/card.dart';
import 'package:kotobaten/models/slices/practice/impression.dart';
import 'package:kotobaten/models/slices/user/user.dart';
import 'package:kotobaten/models/slices/user/user_core.dart';
import 'package:kotobaten/models/slices/user/user_goals.dart';
import 'package:kotobaten/models/slices/user/user_statistics.dart';
import 'package:kotobaten/services/app_configuration.dart';
import 'package:kotobaten/services/cookies_service.dart';
import 'package:kotobaten/services/cookies_service_base.dart';
import 'package:kotobaten/services/kotobaten_client.dart';
import 'package:kotobaten/services/serialization/requests/impressions_request.dart';
import 'package:kotobaten/services/serialization/responses/cards_response.dart';
import 'package:kotobaten/services/serialization/responses/impressions_response.dart';
import 'package:kotobaten/services/serialization/responses/practice_response.dart';
import 'package:mockito/annotations.dart';

final kotobatenApiServiceProvider = Provider((ref) => KotobatenApiService(
    ref.watch(authRepositoryProvider.notifier),
    ref.watch(appConfigurationProvider),
    ref.watch(kotobatenClientProvider),
    ref.read(cookiesServiceProvider)));

class KotobatenApiService {
  // Not using AuthService as it'd cause a cyclical dependency.
  final AuthRepository authRepository;
  final AppConfiguration _appConfiguration;
  final KotobatenClient _kotobatenClient;
  final CookiesServiceBase _cookiesService;

  KotobatenApiService(this.authRepository, this._appConfiguration,
      this._kotobatenClient, this._cookiesService);

  Future<AuthResult> login(String username, String password) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'auth/login');

    try {
      final loginResponse = await _kotobatenClient.post(url, body: {
        'grant_type': 'password',
        'username': username,
        'password': password
      });

      final body = utf8.decode(loginResponse.bodyBytes);

      if (loginResponse.statusCode != 200) {
        return AuthResult.error(loginResponse.statusCode);
      }

      await _cookiesService.setCookie(
          'authToken', true.toString(), _appConfiguration.cookieDomain);

      final token = jsonDecode(body)['access_token'] as String;
      return AuthResult.success(token);
    } on ClientException catch (e) {
      return AuthResult.exception(e);
    }
  }

  Future<AuthResult> signupAndLogin(String username, String password) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'auth/signup');

    try {
      final loginResponse = await _kotobatenClient.post(url,
          body: json.encode({'email': username, 'password': password}),
          headers: Map.fromEntries([contentTypeJsonHeader]));

      if (loginResponse.statusCode >= 400) {
        return AuthResult.error(loginResponse.statusCode);
      }

      return login(username, password);
    } on ClientException catch (e) {
      return AuthResult.exception(e);
    }
  }

  Future<UserInitialized> getUser(
      {bool updateRetentionBackstop = false}) async {
    var response = await _getAuthenticated('user',
        params: {'overrideBackstop': updateRetentionBackstop.toString()});

    if (response == null) {
      throw ErrorDescription('User not authenticated');
    }

    return UserInitialized.fromJson(response);
  }

  Future<SearchResult> search(String term) async => SearchResult.fromJson(
      await _getAuthenticated('search', params: {'term': term}));

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

  Future generateDemoCards() async {
    await _postJson('demoCards', {});
  }

  Future<bool> deleteCard(int cardId) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'cards/$cardId');

    var headers = await _getTokenHeadersOrThrow();
    headers.addEntries([contentTypeJsonHeader]);

    await _kotobatenClient.delete(url, headers: headers);

    return true;
  }

  Future<UserGoals> updateGoals(UserGoals goals) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'settings/goals', {
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

  Future<CardsResponse> getCards(int page, int pageSize) async {
    final responseJson = await _getAuthenticated('cards',
        params: {'pageSize': pageSize.toString(), 'page': page.toString()});

    final result = CardsResponse.fromJson(responseJson);

    return result;
  }

  Future<UserCoreInitialized> updateRetentionBackstopMaxThreshold(
      int number) async {
    final url = _getUrl(_appConfiguration.apiRoot, 'settings/dailyThreshold', {
      'retentionBackstopMaxThreshold': number.toString(),
    });

    var headers = await _getTokenHeadersOrThrow();
    headers.addEntries([contentTypeJsonHeader]);

    final response = await _kotobatenClient.post(url, headers: headers);
    final body = utf8.decode(response.bodyBytes);
    return UserCoreInitialized.fromJson(jsonDecode(body));
  }

  Future hideOnboarding() async {
    await _postJson('hideOnboarding', {});
  }

  Future<dynamic> _getAuthenticated(String relativePath,
      {Map<String, dynamic>? params}) async {
    final url = _getUrl(_appConfiguration.apiRoot, relativePath, params);

    final response = await _kotobatenClient.get(url,
        headers: await _getTokenHeadersOrThrow());

    if (response.statusCode == 401) {
      authRepository.update(AuthModel.unauthenticated());
      return null;
    }

    final body = utf8.decode(response.bodyBytes);
    return jsonDecode(body);
  }

  Future<Map<String, String>> _getTokenHeadersOrThrow() async {
    final authModel = authRepository.current;
    final token = authModel.getCurrentToken();

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
