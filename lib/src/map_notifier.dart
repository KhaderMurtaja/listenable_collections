import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:functional_listener/functional_listener.dart';

/// A Map that behaves like `ValueNotifier` if its data changes.
/// if [notificationMode] is set to [normal] listeners
/// are only notified if a value is set that is not equal to the value
/// currently stored with that key. If set to [always], listeners would be notified
/// of any values that are passed, even when equal. If set to [manual], listeners
/// would not be notified of any values that are passed, even when not equal.
/// You have to call [notifyListeners] in this case manually.
///
/// For example, if [notificationMode] is set to [normal], the code below will not notify
/// listeners:
/// '''
///   final mapNotifier = MapNotifier(data: {'one': 1});
///   mapNotifier['one'] = 1
/// '''
class MapNotifier<K, V> extends DelegatingMap<K, V>
    with ChangeNotifier
    implements ValueListenable<Map<K, V>> {
  /// Creates a new listenable Map
  /// [data] optional map that should be used as initial value
  /// [notificationMode] determines whether to notify listeners if an equal value is assigned to
  /// a key. To not make users wonder why their UI doesn't update if they
  /// assign the same value to a key, the default is [always].
  /// [customEquality] can be used to set your own criteria for comparing
  /// values, which might be important notificationMode is set to [normal].
  MapNotifier({
    Map<K, V>? data,
    CustomNotifierMode notificationMode = CustomNotifierMode.always,
    this.customEquality,
  })  : _notificationMode = notificationMode,
        super(data ?? {});

  /// Determines whether to notify listeners if an equal value is assigned to
  /// a key.
  /// For example, if set to [normal] , the code below will not notify
  /// listeners:
  /// '''
  ///   final mapNotifier = MapNotifier(data: {'one': 1});
  ///   mapNotifier['one'] = 1
  /// '''
  /// If set to [always], listeners would be notified of any values that are
  /// assigned, even when equal.
  /// If set to [manual], listeners would not be notified of any values that are
  /// assigned, even when not equal. You have to call [notifyListeners] manually
  final CustomNotifierMode _notificationMode;

  /// [customEquality] can be used to set your own criteria for comparing
  /// values, which might be important if [notifyIfEqual] is false. The function
  /// should return a bool that represents if, when compared, two values are
  /// equal. If null, the default values equality [==] is used.
  final bool Function(V? x, V? y)? customEquality;

  /// if this is `true` no listener will be notified if the list changes.
  bool _inTransaction = false;
  bool _hasChanged = false;

  /// Starts a transaction that allows to make multiple changes to the List
  /// with only one notification at the end.
  void startTransAction() {
    assert(!_inTransaction, 'Only one transaction at a time in a MapNotifier');
    _inTransaction = true;
  }

  /// Ends a transaction
  void endTransAction() {
    assert(_inTransaction, 'No active transaction in a MapNotifier');
    _inTransaction = false;
    _notify(true);
  }

  @override
  Map<K, V> get value => UnmodifiableMapView(this);

  @override
  V? operator [](Object? key) => super[key];

  @override
  operator []=(K key, V value) {
    final areEqual = customEquality == null
        ? super[key] == value
        : customEquality!(super[key], value);
    super[key] = value;

    _hasChanged = !areEqual;
    _notify();
  }

  @override
  void addAll(Map<K, V> other) {
    if (_notificationMode == CustomNotifierMode.normal) {
      // we only want to do a full comparison if we care about notifying
      final initialMapValue = {...this};
      super.addAll(other);
      _hasChanged = !_areEqual(initialMapValue);
    } else {
      super.addAll(other);
    }

    super.addAll(other);

    _notify();
  }

  /// A method to compare between two maps, this Map Notifier and any other
  /// map that has been passed to it
  bool _areEqual(Map<K, V> other) {
    if (this.length != other.length) {
      return false;
    }

    for (final key in keys) {
      final areValuesEqual = customEquality?.call(this[key], other[key]) ??
          this[key] == other[key];
      if (!areValuesEqual) {
        return false;
      }
    }

    return true;
  }

  void _notify([bool endofTransaction = false]) {
    if (_inTransaction && !endofTransaction) {
      return;
    }
    switch (_notificationMode) {
      case CustomNotifierMode.normal:
        if (_hasChanged) {
          notifyListeners();
        }
        break;
      case CustomNotifierMode.always:
        notifyListeners();
        break;
      case CustomNotifierMode.manual:
        break;
    }
    _hasChanged = false;
  }

  void notifyListeners() {
    super.notifyListeners();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    if (_notificationMode == CustomNotifierMode.normal) {
      // we only want to do a full comparison if we care about notifying
      final initialMapValue = {...this};
      super.addEntries(entries);
      _hasChanged = !_areEqual(initialMapValue);
    } else {
      super.addEntries(entries);
    }

    _notify();
  }

  @override
  void clear() {
    _hasChanged = isNotEmpty;
    super.clear();
    _notify();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final exists = containsKey(key);
    if (!exists) {
      final value = ifAbsent();
      super[key] = value;
      _hasChanged = true;
      _notify();
      return value;
    }
    return this[key]!;
  }

  @override
  V? remove(Object? key) {
    final lookedUpValue = this[key];
    if (lookedUpValue != null) {
      _hasChanged = true;
    }
    super.remove(key);
    _notify();

    return lookedUpValue;
  }

  @override
  void removeWhere(bool Function(K, V) test) {
    super.removeWhere((key, value) {
      final result = test(key, value);
      if (result) {
        _hasChanged = true;
      }
      return result;
    });

    _notify();
  }

  @override
  V update(K key, V Function(V) update, {V Function()? ifAbsent}) {
    final lookedUpValue = this[key];

    if (lookedUpValue != null) {
      final newValue = update(lookedUpValue);
      super[key] = newValue;
      _hasChanged = newValue != lookedUpValue;
      _notify();
      return newValue;
    }

    return super.update(key, update, ifAbsent: ifAbsent);
  }

  @override
  void updateAll(V Function(K, V) update) {
    super.updateAll((key, value) {
      final newValue = update(key, value);
      _hasChanged = newValue != value;
      return newValue;
    });

    _notify();
  }
}
