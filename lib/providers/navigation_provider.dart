import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isNavVisible = true;

  int get currentIndex => _currentIndex;
  bool get isNavVisible => _isNavVisible;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    _isNavVisible = true;
    notifyListeners();
  }

  void resetToHome() {
    setIndex(0);
  }

  void showNav() {
    if (_isNavVisible) return;
    _isNavVisible = true;
    notifyListeners();
  }

  void hideNav() {
    if (!_isNavVisible) return;
    _isNavVisible = false;
    notifyListeners();
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.reverse:
          hideNav();
          break;
        case ScrollDirection.forward:
        case ScrollDirection.idle:
          showNav();
          break;
      }
    }

    return false;
  }
}
