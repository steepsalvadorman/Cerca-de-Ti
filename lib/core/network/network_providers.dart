import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';
import 'token_storage.dart';

part 'network_providers.g.dart';

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => const TokenStorage();

@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) => buildApiClient(ref, ref.watch(tokenStorageProvider));
