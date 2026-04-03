import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comment_model.dart';

class MainState {
  final bool isLive;
  final String? connectedUsername;
  final List<CommentModel> comments;

  const MainState({
    this.isLive = false,
    this.connectedUsername,
    this.comments = const [],
  });

  MainState copyWith({
    bool? isLive,
    String? connectedUsername,
    List<CommentModel>? comments,
    bool clearConnectedUsername = false,
  }) {
    return MainState(
      isLive: isLive ?? this.isLive,
      connectedUsername: clearConnectedUsername
          ? null
          : (connectedUsername ?? this.connectedUsername),
      comments: comments ?? this.comments,
    );
  }
}

class MainNotifier extends Notifier<MainState> {
  @override
  MainState build() => const MainState();

  void startLive(String username) {
    state = state.copyWith(
      isLive: true,
      connectedUsername: username,
    );
  }

  void stopLive() {
    state = state.copyWith(
      isLive: false,
      clearConnectedUsername: true,
    );
  }

  void addComment(CommentModel comment) {
    final updated = <CommentModel>[comment, ...state.comments];
    state = state.copyWith(
      comments: updated.length > 200 ? updated.take(200).toList() : updated,
    );
  }

  void clearComments() {
    state = state.copyWith(comments: const []);
  }
}

final mainProvider =
    NotifierProvider<MainNotifier, MainState>(MainNotifier.new);
