import 'package:dali_camera/watermark_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DALI2 identity round-trips without a server', () {
    final encoded = createDali2Watermark(
      ownerId: 'canonical-owner',
      photoId: 'unique-photo',
      publicId: 'GLICX-PHOTO',
    );
    final identity = parseDaliWatermarkIdentity(encoded);
    expect(encoded, startsWith('DALI2-'));
    expect(identity?.version, 2);
    expect(identity?.ownerId, 'canonical-owner');
    expect(identity?.photoId, 'unique-photo');
    expect(identity?.publicId, 'GLICX-PHOTO');
    expect(identity?.legacy, isFalse);
  });

  test('legacy IDs remain detectable and malformed DALI2 is rejected', () {
    final legacy = parseDaliWatermarkIdentity('DALI1-legacy-token');
    expect(legacy?.legacy, isTrue);
    expect(isDaliMetadataWatermark('DALI1-legacy-token'), isTrue);
    expect(isDaliMetadataWatermark('DALI2-not-base64'), isFalse);
    expect(isDaliMetadataWatermark('OTHER-token'), isFalse);
  });

  test('pixel references are compact and deterministic', () {
    expect(daliPixelReference('owner-phase2-android'), hasLength(8));
    expect(
      daliPixelReference('owner-phase2-android'),
      daliPixelReference('owner-phase2-android'),
    );
    expect(
      daliPixelReference('owner-phase2-android'),
      isNot(daliPixelReference('photo-phase2-android')),
    );
  });

  test('identity recovery code round-trips owner and public IDs', () {
    final code = createDaliIdentityRecovery(
      ownerId: 'owner_phase3_1234',
      publicId: 'GLICX-PHOTO',
    );
    final recovery = parseDaliIdentityRecovery('  $code\n');
    expect(code, startsWith('DALI-IDENTITY-RECOVERY-V1.'));
    expect(recovery?.ownerId, 'owner_phase3_1234');
    expect(recovery?.publicId, 'GLICX-PHOTO');
  });

  test('identity recovery rejects damaged and invalid codes', () {
    final code = createDaliIdentityRecovery(ownerId: 'owner_phase3_1234');
    expect(parseDaliIdentityRecovery('${code}x'), isNull);
    expect(
      parseDaliIdentityRecovery('DALI-IDENTITY-RECOVERY-V1.bad.00000000'),
      isNull,
    );
    expect(
      () => createDaliIdentityRecovery(ownerId: 'short'),
      throwsArgumentError,
    );
  });
}
