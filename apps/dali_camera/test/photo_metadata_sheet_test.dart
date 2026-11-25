import 'package:dali_camera/photo_metadata_sheet.dart';
import 'package:dali_camera/watermark_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits descriptive metadata and preserves empty fields', (
    tester,
  ) async {
    Map<String, String>? saved;
    final watermarkId = createDali2Watermark(
      ownerId: 'owner-test-1234',
      photoId: 'photo-test-5678',
      publicId: 'GLICX-PHOTO',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoMetadataSheet(
            title: 'Photo.jpg',
            metadata: Future.value({
              'description': 'Original description',
              'artist': 'Original creator',
              'copyright': 'Original copyright',
              'hiddenWatermark': watermarkId,
              'hiddenPixelWatermark': true,
              'hiddenPixelWatermarkVersion': 'DALI_PIXEL_V3',
              'hiddenPixelWatermarkOwnerReference': daliPixelReference(
                'owner-test-1234',
              ),
              'hiddenPixelWatermarkPhotoReference': daliPixelReference(
                'photo-test-5678',
              ),
              'hiddenPixelWatermarkPayloadConfidence': .94,
              'hiddenPixelWatermarkPayloadRecovery': 'tiled',
              'signedWatermarkStatus': 'verified',
              'signedWatermarkOwnerReference': daliPixelReference(
                'owner-test-1234',
              ),
              'signedWatermarkPhotoReference': daliPixelReference(
                'photo-test-5678',
              ),
              'signedWatermarkKeyFingerprint':
                  '00112233445566778899aabbccddeeff',
              'hiddenPixelWatermarkScore': 3.25,
              'hiddenPixelWatermarkSamples': 60000,
              'hiddenPixelWatermarkMinimumDimension': 64,
              'hiddenPixelWatermarkRobustScore': 9.75,
              'hiddenPixelWatermarkRobustAxis': 'vertical',
              'hiddenPixelWatermarkRobustQuarterTurns': 1,
              'hiddenPixelWatermarkDetectionMillis': 42,
              'width': 1200,
              'height': 800,
            }),
            localWatermarkOwnerId: 'owner-test-1234',
            onEdit: (metadata) async {
              saved = metadata;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original description'), findsOneWidget);
    expect(find.textContaining('Identifier present'), findsOneWidget);
    expect(find.textContaining('Identity payload recovered'), findsOneWidget);
    expect(find.textContaining('Dali Pixel v3'), findsOneWidget);
    expect(
      find.textContaining('tiled crop/rotation-resilient'),
      findsOneWidget,
    );
    expect(find.textContaining('Robust score 9.75'), findsOneWidget);
    expect(find.textContaining('rotation normalized'), findsOneWidget);
    expect(find.text('Local detection took 42 ms.'), findsOneWidget);
    expect(
      find.textContaining('Pixel and metadata identities agree'),
      findsOneWidget,
    );
    expect(find.text('Offline signature verified'), findsOneWidget);
    expect(
      find.text('Signed manifest and pixel identity agree.'),
      findsOneWidget,
    );
    expect(find.textContaining('Detection score 3.250'), findsOneWidget);
    expect(find.text('Full watermark ID'), findsOneWidget);
    expect(find.text(watermarkId), findsOneWidget);
    expect(find.text('GLICX-PHOTO'), findsOneWidget);
    expect(find.text('owner-test-1234'), findsOneWidget);
    expect(find.text('photo-test-5678'), findsOneWidget);
    expect(find.text('Your offline watermark'), findsOneWidget);
    expect(
      find.text('The owner ID matches this device profile.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('copyMetadataWatermarkId')), findsOneWidget);
    await tester.tap(find.byKey(const Key('editPhotoMetadata')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('photoMetadataDescription')),
      'Updated description',
    );
    await tester.enterText(
      find.byKey(const Key('photoMetadataCreator')),
      'Updated creator',
    );
    await tester.enterText(find.byKey(const Key('photoMetadataCopyright')), '');
    await tester.ensureVisible(
      find.byKey(const Key('photoMetadataHiddenWatermark')),
    );
    await tester.tap(find.byKey(const Key('photoMetadataHiddenWatermark')));
    await tester.tap(find.byKey(const Key('savePhotoMetadata')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['description'], 'Updated description');
    expect(saved!['artist'], 'Updated creator');
    expect(saved!['copyright'], '');
    expect(saved!['hiddenWatermark'], '');
    expect(saved!['dateOriginal'], '');
    expect(saved!['latitude'], '');
  });

  testWidgets('viewer sees a watermark from another offline profile', (
    tester,
  ) async {
    final watermarkId = createDali2Watermark(
      ownerId: 'photographer-owner',
      photoId: 'photo-from-photographer',
      publicId: 'OTHER-PHOTO',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoMetadataSheet(
            title: 'Shared.jpg',
            metadata: Future.value({
              'hiddenWatermark': watermarkId,
              'hiddenPixelWatermark': true,
              'hiddenPixelWatermarkVersion': 'DALI_PIXEL_V2',
              'hiddenPixelWatermarkOwnerReference': daliPixelReference(
                'different-owner',
              ),
              'hiddenPixelWatermarkPhotoReference': daliPixelReference(
                'different-photo',
              ),
              'signedWatermarkStatus': 'metadata_conflict',
              'signedWatermarkOwnerReference': daliPixelReference(
                'photographer-owner',
              ),
              'signedWatermarkPhotoReference': daliPixelReference(
                'photo-from-photographer',
              ),
              'signedWatermarkKeyFingerprint':
                  'ffeeddccbbaa99887766554433221100',
            }),
            localWatermarkOwnerId: 'viewer-owner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watermark from another Dali profile'), findsOneWidget);
    expect(
      find.text('The owner ID does not match this device profile.'),
      findsOneWidget,
    );
    expect(find.text('OTHER-PHOTO'), findsOneWidget);
    expect(find.text('photographer-owner'), findsOneWidget);
    expect(find.text('photo-from-photographer'), findsOneWidget);
    expect(
      find.text('Warning: Pixel and metadata identities conflict.'),
      findsOneWidget,
    );
    expect(find.text('Signed identity conflict'), findsOneWidget);
  });

  testWidgets('edits capture, exposure, and location metadata', (tester) async {
    Map<String, String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoMetadataSheet(
            title: 'Photo.jpg',
            metadata: Future.value({
              'dateOriginal': '2026:11:24 15:33:20',
              'iso': '346',
              'width': 1200,
              'height': 800,
            }),
            onEdit: (metadata) async {
              saved = metadata;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editPhotoMetadata')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Description and rights'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Capture and equipment'));
    await tester.tap(find.text('Capture and equipment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('photoMetadata_dateOriginal')),
    );
    await tester.enterText(
      find.byKey(const Key('photoMetadata_dateOriginal')),
      '2026:12:01 09:30:15',
    );
    await tester.ensureVisible(find.text('Capture and equipment'));
    await tester.tap(find.text('Capture and equipment'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Exposure details'));
    await tester.tap(find.text('Exposure details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('photoMetadata_iso')));
    await tester.enterText(find.byKey(const Key('photoMetadata_iso')), '400');
    await tester.ensureVisible(find.text('Exposure details'));
    await tester.tap(find.text('Exposure details'));
    await tester.pumpAndSettle();

    final locationSection = find.byKey(
      const Key('photoMetadataSection_latitude'),
    );
    await tester.ensureVisible(locationSection);
    await tester.tap(locationSection);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('photoMetadata_latitude')));
    await tester.enterText(
      find.byKey(const Key('photoMetadata_latitude')),
      '37.7749',
    );
    await tester.tap(find.byKey(const Key('savePhotoMetadata')));
    await tester.pump();
    expect(
      find.text('Latitude and longitude must be entered together.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('photoMetadata_longitude')),
      '-122.4194',
    );
    await tester.tap(find.byKey(const Key('savePhotoMetadata')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['dateOriginal'], '2026:12:01 09:30:15');
    expect(saved!['iso'], '400');
    expect(saved!['latitude'], '37.7749');
    expect(saved!['longitude'], '-122.4194');
  });
}
