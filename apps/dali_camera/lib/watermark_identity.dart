import 'dart:convert';

class DaliWatermarkIdentity {
  const DaliWatermarkIdentity({
    required this.fullId,
    required this.version,
    this.ownerId,
    this.photoId,
    this.publicId,
  });

  final String fullId;
  final int version;
  final String? ownerId;
  final String? photoId;
  final String? publicId;

  bool get legacy => version == 1;
}

class DaliIdentityRecovery {
  const DaliIdentityRecovery({required this.ownerId, required this.publicId});

  final String ownerId;
  final String publicId;
}

const _recoveryPrefix = 'DALI-IDENTITY-RECOVERY-V1.';
final _ownerIdPattern = RegExp(r'^[A-Za-z0-9_-]{12,64}$');
final _publicIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,39}$');

bool isDaliMetadataWatermark(dynamic value) =>
    parseDaliWatermarkIdentity(value) != null;

DaliWatermarkIdentity? parseDaliWatermarkIdentity(dynamic rawValue) {
  if (rawValue is! String) return null;
  if (rawValue.startsWith('DALI1-') && rawValue.length > 6) {
    return DaliWatermarkIdentity(fullId: rawValue, version: 1);
  }
  if (!rawValue.startsWith('DALI2-')) return null;
  try {
    final encoded = rawValue.substring(6);
    final normalized = base64Url.normalize(encoded);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (payload is! Map || payload['v'] != 2) return null;
    final ownerId = payload['owner'];
    final photoId = payload['photo'];
    final publicId = payload['public'];
    if (ownerId is! String || ownerId.isEmpty) return null;
    if (photoId is! String || photoId.isEmpty) return null;
    if (publicId != null && publicId is! String) return null;
    final normalizedPublicId = publicId?.trim();
    return DaliWatermarkIdentity(
      fullId: rawValue,
      version: 2,
      ownerId: ownerId,
      photoId: photoId,
      publicId: normalizedPublicId?.isEmpty == true ? null : normalizedPublicId,
    );
  } catch (_) {
    return null;
  }
}

String createDali2Watermark({
  required String ownerId,
  required String photoId,
  String? publicId,
}) {
  final payload = <String, dynamic>{
    'v': 2,
    'owner': ownerId,
    'photo': photoId,
    if (publicId?.trim().isNotEmpty == true) 'public': publicId!.trim(),
  };
  final encoded = base64UrlEncode(
    utf8.encode(jsonEncode(payload)),
  ).replaceAll('=', '');
  return 'DALI2-$encoded';
}

String daliPixelReference(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String createDaliIdentityRecovery({required String ownerId, String? publicId}) {
  if (!_ownerIdPattern.hasMatch(ownerId)) {
    throw ArgumentError.value(ownerId, 'ownerId', 'Invalid owner ID');
  }
  final normalizedPublicId = publicId?.trim() ?? '';
  if (normalizedPublicId.isNotEmpty &&
      !_publicIdPattern.hasMatch(normalizedPublicId)) {
    throw ArgumentError.value(publicId, 'publicId', 'Invalid public ID');
  }
  final payload = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'owner': ownerId,
        if (normalizedPublicId.isNotEmpty) 'public': normalizedPublicId,
      }),
    ),
  ).replaceAll('=', '');
  return '$_recoveryPrefix$payload.${daliPixelReference(payload)}';
}

DaliIdentityRecovery? parseDaliIdentityRecovery(dynamic rawValue) {
  if (rawValue is! String) return null;
  final value = rawValue.trim();
  if (!value.startsWith(_recoveryPrefix)) return null;
  final encodedAndChecksum = value.substring(_recoveryPrefix.length);
  final separator = encodedAndChecksum.lastIndexOf('.');
  if (separator <= 0 || separator == encodedAndChecksum.length - 1) return null;
  final encoded = encodedAndChecksum.substring(0, separator);
  final checksum = encodedAndChecksum.substring(separator + 1).toLowerCase();
  if (checksum != daliPixelReference(encoded)) return null;
  try {
    final normalized = base64Url.normalize(encoded);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (payload is! Map || payload['v'] != 1) return null;
    final ownerId = payload['owner'];
    final publicId = payload['public'];
    if (ownerId is! String || !_ownerIdPattern.hasMatch(ownerId)) return null;
    if (publicId != null &&
        (publicId is! String || !_publicIdPattern.hasMatch(publicId))) {
      return null;
    }
    return DaliIdentityRecovery(
      ownerId: ownerId,
      publicId: publicId as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}
