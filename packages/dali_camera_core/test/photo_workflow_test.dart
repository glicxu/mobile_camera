import 'dart:async';
import 'dart:typed_data';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

class MemoryStore implements PendingPhotoStore {
  Uint8List? bytes;
  bool failWrite = false;
  @override
  Future<Uint8List?> load() async => bytes;
  @override
  Future<void> retain(Uint8List original) async {
    if (failWrite) throw StateError('Disk full');
    bytes = Uint8List.fromList(original);
  }

  @override
  Future<void> remove() async {
    bytes = null;
  }
}

class FakeLibrary implements PhotoLibraryWriter {
  bool denied = false;
  Completer<void>? gate;
  final saved = <Uint8List>[];
  @override
  Future<void> save(Uint8List bytes) async {
    if (gate != null) await gate!.future;
    if (denied) throw StateError('Photos permission denied');
    saved.add(bytes);
  }
}

void main() {
  test('denied save survives recreation and can be retried', () async {
    final store = MemoryStore();
    final library = FakeLibrary()..denied = true;
    final first = PhotoWorkflow(store: store, library: library);
    expect(first.beginCapture(), isTrue);
    expect(first.beginCapture(), isFalse);
    await first.captured(Uint8List.fromList([1, 2, 3]));
    expect(first.saveState, PhotoSaveState.failed);
    expect(first.canCapture, isFalse);
    final reopened = PhotoWorkflow(store: store, library: library);
    await reopened.restore();
    expect(reopened.original, [1, 2, 3]);
    library.denied = false;
    await reopened.retryOriginal();
    expect(reopened.canCapture, isTrue);
    expect(store.bytes, isNull);
    expect(library.saved.single, [1, 2, 3]);
  });

  test('selected variant retry does not replace original', () async {
    final library = FakeLibrary();
    final flow = PhotoWorkflow(store: MemoryStore(), library: library);
    flow.beginCapture();
    await flow.captured(Uint8List.fromList([1]));
    library.denied = true;
    final variant = Uint8List.fromList([9]);
    await flow.saveCopy(variant);
    variant[0] = 8;
    library.denied = false;
    await flow.retryCopy();
    expect(library.saved.last, [9]);
    expect(flow.original, [1]);
    expect(flow.canRetryCopy, isFalse);
  });

  test('pending save blocks duplicate save, discard and capture', () async {
    final library = FakeLibrary()..gate = Completer<void>();
    final flow = PhotoWorkflow(store: MemoryStore(), library: library);
    flow.beginCapture();
    final pending = flow.captured(Uint8List.fromList([1]));
    expect(flow.beginCapture(), isFalse);
    await flow.discardOriginal();
    await flow.retryOriginal();
    expect(flow.original, [1]);
    library.gate!.complete();
    await pending;
    expect(library.saved, hasLength(1));
  });

  test('failed recovery write still retains in-memory original', () async {
    final store = MemoryStore()..failWrite = true;
    final flow = PhotoWorkflow(
      store: store,
      library: FakeLibrary()..denied = true,
    );
    flow.beginCapture();
    await flow.captured(Uint8List.fromList([7]));
    expect(flow.recoveryWriteFailed, isTrue);
    expect(flow.original, [7]);
    expect(flow.hasUnsavedOriginal, isTrue);
    await flow.discardOriginal();
    expect(flow.original, isNull);
    expect(flow.canCapture, isTrue);
  });
}
