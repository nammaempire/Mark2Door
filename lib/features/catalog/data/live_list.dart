import 'dart:async';

/// One update from a live source: the whole list as it now stands.
class LiveSnapshot<T> {
  const LiveSnapshot(
    this.items, {
    required this.fromCache,
    required this.changed,
  });

  final List<T> items;

  /// True when this is the copy the phone saved earlier, not yet
  /// confirmed by the server.
  final bool fromCache;

  /// False for a note that the server agrees with what was already sent.
  final bool changed;
}

/// A list read once and then kept current by a live connection, for as
/// long as the app is open. Asking for it again answers from memory.
class LiveList<T> {
  LiveList(this._source, this._onChange, {this.patience = _defaultPatience});

  static const _defaultPatience = Duration(seconds: 15);

  /// Opens the live connection.
  final Stream<LiveSnapshot<T>> Function() _source;

  /// Called when the list changes after its first load.
  final void Function() _onChange;

  /// How long the first load may take before it is given up.
  final Duration patience;

  StreamSubscription<LiveSnapshot<T>>? _sub;
  Completer<void>? _ready;
  List<T> _items = const [];

  /// True while the live connection is open.
  bool get connected => _sub != null;

  /// The list: waits for the first load, then answers from memory.
  Future<List<T>> items() async {
    if (_sub == null) _connect();
    await _ready!.future.timeout(
      patience,
      onTimeout: () {
        _disconnect();
        throw TimeoutException('The list did not load');
      },
    );
    return _items;
  }

  void _connect() {
    final ready = _ready = Completer<void>();
    _sub = _source().listen(
      (snap) {
        // What the phone saved last time shows at once; an empty saved
        // copy is not trusted until the server has answered.
        if (snap.fromCache && snap.items.isEmpty) return;
        final first = !ready.isCompleted;
        // The server agreeing with the saved copy changes nothing.
        if (!first && !snap.changed) return;
        _items = snap.items;
        if (first) {
          ready.complete();
        } else {
          _onChange();
        }
      },
      onError: (Object error) {
        // Signed out, or the connection was refused: start afresh on
        // the next request.
        if (!ready.isCompleted) ready.completeError(error);
        _disconnect();
      },
    );
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
  }
}
