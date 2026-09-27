// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'f5dad0172bd53aeb96deaedceab732e34a9fa31d';

/// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
/// screen — the backend has no push/websocket support.

@ProviderFor(chatMessages)
final chatMessagesProvider = ChatMessagesFamily._();

/// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
/// screen — the backend has no push/websocket support.

final class ChatMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          Stream<List<ChatMessage>>
        >
    with
        $FutureModifier<List<ChatMessage>>,
        $StreamProvider<List<ChatMessage>> {
  /// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
  /// screen — the backend has no push/websocket support.
  ChatMessagesProvider._({
    required ChatMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatMessagesHash();

  @override
  String toString() {
    return r'chatMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return chatMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatMessagesHash() => r'd426e89a0928f5ce3cedb11a41dfd57538c5a353';

/// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
/// screen — the backend has no push/websocket support.

final class ChatMessagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChatMessage>>, String> {
  ChatMessagesFamily._()
    : super(
        retry: null,
        name: r'chatMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
  /// screen — the backend has no push/websocket support.

  ChatMessagesProvider call(String jobId) =>
      ChatMessagesProvider._(argument: jobId, from: this);

  @override
  String toString() => r'chatMessagesProvider';
}

/// The inbox, refreshed on a slower beat than an open thread: it only
/// drives previews and unread badges. Watched by the tab bar, so it keeps
/// polling on every tab, not just while the inbox is on screen.

@ProviderFor(chatConversations)
final chatConversationsProvider = ChatConversationsProvider._();

/// The inbox, refreshed on a slower beat than an open thread: it only
/// drives previews and unread badges. Watched by the tab bar, so it keeps
/// polling on every tab, not just while the inbox is on screen.

final class ChatConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatConversation>>,
          List<ChatConversation>,
          Stream<List<ChatConversation>>
        >
    with
        $FutureModifier<List<ChatConversation>>,
        $StreamProvider<List<ChatConversation>> {
  /// The inbox, refreshed on a slower beat than an open thread: it only
  /// drives previews and unread badges. Watched by the tab bar, so it keeps
  /// polling on every tab, not just while the inbox is on screen.
  ChatConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatConversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatConversationsHash();

  @$internal
  @override
  $StreamProviderElement<List<ChatConversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatConversation>> create(Ref ref) {
    return chatConversations(ref);
  }
}

String _$chatConversationsHash() => r'5563b62644d5c4d07d14175b31a22a9a6a81ad64';

/// Total unread messages across every conversation, for the tab badge.

@ProviderFor(chatUnreadTotal)
final chatUnreadTotalProvider = ChatUnreadTotalProvider._();

/// Total unread messages across every conversation, for the tab badge.

final class ChatUnreadTotalProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Total unread messages across every conversation, for the tab badge.
  ChatUnreadTotalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatUnreadTotalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatUnreadTotalHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return chatUnreadTotal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$chatUnreadTotalHash() => r'5f10261fbe2c00a6e716e5927c655b6e55c31cd6';
