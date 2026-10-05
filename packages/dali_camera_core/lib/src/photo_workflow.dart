import 'dart:typed_data';

/// Native adapters implement atomic private storage and Photos permission/save.
abstract interface class PendingPhotoStore {
  Future<Uint8List?> load();
  Future<void> retain(Uint8List original);
  Future<void> remove();
}

abstract interface class PhotoLibraryWriter {
  Future<void> save(Uint8List bytes);
}

enum PhotoSaveState { idle, saving, saved, failed }

/// UI-independent capture/review recovery contract. Never edits original bytes.
class PhotoWorkflow {
  PhotoWorkflow({required this.store, required this.library});
  final PendingPhotoStore store;
  final PhotoLibraryWriter library;
  Uint8List? _original;
  Uint8List? _pendingCopy;
  bool hasUnsavedOriginal = false;
  bool isCapturing = false;
  bool isRestoring = false;
  bool recoveryWriteFailed = false;
  PhotoSaveState saveState = PhotoSaveState.idle;
  Object? lastError;

  Uint8List? get original =>
      _original == null ? null : Uint8List.fromList(_original!);
  bool get canCapture =>
      !isCapturing &&
      !isRestoring &&
      !hasUnsavedOriginal &&
      saveState != PhotoSaveState.saving;
  bool get canRetryCopy =>
      _pendingCopy != null && saveState != PhotoSaveState.saving;

  Future<void> restore() async {
    if (!canCapture || _original != null) throw StateError('Workflow is busy');
    isRestoring = true;
    try {
      final recovered = await store.load();
      _original = recovered == null ? null : Uint8List.fromList(recovered);
      hasUnsavedOriginal = _original != null;
    } finally {
      isRestoring = false;
    }
  }

  bool beginCapture() {
    if (!canCapture) return false;
    isCapturing = true;
    lastError = null;
    return true;
  }

  void captureFailed(Object error) {
    isCapturing = false;
    lastError = error;
  }

  Future<void> captured(Uint8List bytes) async {
    if (!isCapturing) throw StateError('No capture is in progress');
    _original = Uint8List.fromList(bytes);
    hasUnsavedOriginal = true;
    isCapturing = false;
    recoveryWriteFailed = false;
    // Reserve the save slot before yielding to storage.
    saveState = PhotoSaveState.saving;
    try {
      await store.retain(Uint8List.fromList(_original!));
    } catch (error) {
      recoveryWriteFailed = true;
      lastError = error;
    }
    await _save(_original!, original: true);
  }

  Future<void> retryOriginal() async {
    if (!hasUnsavedOriginal || saveState == PhotoSaveState.saving) return;
    saveState = PhotoSaveState.saving;
    await _save(_original!, original: true);
  }

  Future<void> saveCopy(Uint8List selectedVariant) async {
    if (isCapturing || isRestoring || saveState == PhotoSaveState.saving) {
      return;
    }
    _pendingCopy = Uint8List.fromList(selectedVariant);
    saveState = PhotoSaveState.saving;
    await _save(_pendingCopy!, original: false);
  }

  Future<void> retryCopy() async {
    if (!canRetryCopy) return;
    saveState = PhotoSaveState.saving;
    await _save(_pendingCopy!, original: false);
  }

  Future<void> _save(Uint8List bytes, {required bool original}) async {
    try {
      await library.save(Uint8List.fromList(bytes));
    } catch (error) {
      lastError = error;
      saveState = PhotoSaveState.failed;
      return;
    }
    if (original) {
      hasUnsavedOriginal = false;
      try {
        await store.remove();
      } catch (error) {
        // A redundant recovery copy is preferable to losing an original.
        lastError = error;
      }
    } else {
      _pendingCopy = null;
    }
    saveState = PhotoSaveState.saved;
  }

  Future<void> discardOriginal() async {
    if (isCapturing || isRestoring || saveState == PhotoSaveState.saving) {
      return;
    }
    await store.remove();
    _original = null;
    hasUnsavedOriginal = false;
  }
}
