import 'package:flutter/foundation.dart';

class AppStateService {
  AppStateService._();

  static final AppStateService instance = AppStateService._();

  final ValueNotifier<int> currentTab = ValueNotifier<int>(0);
  final ValueNotifier<int> unreadMessages = ValueNotifier<int>(0);
  final ValueNotifier<int> messagesVersion = ValueNotifier<int>(0);
  final ValueNotifier<bool> isOnline =
      ValueNotifier<bool>(true);
  final ValueNotifier<int> localDataResetVersion = ValueNotifier<int>(0);

  void setCurrentTab(int tabIndex) {
    currentTab.value = tabIndex;
    if (tabIndex == 4) {
      resetUnreadMessages();
    }
  }

  void setOnline(bool online) {
    if (isOnline.value == online) return;
    isOnline.value = online;
  }

  void setUnreadMessages(int count) {
    unreadMessages.value = count < 0 ? 0 : count;
  }

  void incrementUnreadMessages() {
    unreadMessages.value = unreadMessages.value + 1;
  }

  void resetUnreadMessages() {
    unreadMessages.value = 0;
  }

  void bumpMessagesVersion() {
    messagesVersion.value = messagesVersion.value + 1;
  }

  void notifyLocalDataCleared() {
    resetUnreadMessages();
    bumpMessagesVersion();
    localDataResetVersion.value = localDataResetVersion.value + 1;
  }
}
