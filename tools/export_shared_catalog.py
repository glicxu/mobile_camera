"""Export implemented Swift catalogs and validate every case/asset for Flutter.

Swift remains the catalog authoring source during coexistence. Unsupported syntax
fails instead of silently dropping metadata. Run with --check in CI.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import io
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'DaliCamera/Models.swift'
text = SOURCE.read_text(encoding='utf-8')
export_check = False


def enum(name):
    start = text.index('enum ' + name + ':')
    end = text.find('\nenum ', start + 5)
    return text[start:end if end >= 0 else len(text)]


def property_cases(block, name):
    match = re.search(r'var ' + name + r':[^\{]+\{', block)
    if not match:
        raise ValueError(name)
    start = match.end()
    depth, end = 1, start
    while depth:
        depth += (block[end] == '{') - (block[end] == '}')
        end += 1
    body = block[start:end - 1]
    result = {}
    fallback = re.search(r'default:\s*return\s+\.(\w+)', body)
    if fallback:
        result['_default'] = fallback.group(1)
    for cases, value in re.findall(r'case\s+(.+?):\s*return\s+([^\n]+)', body, re.S):
        # Match stops at return line; subsequent cases are independent.
        for case in re.findall(r'\.(\w+)', cases):
            if value.strip().startswith('['):
                parsed = json.loads(value.strip())
            elif value.strip().startswith('"'):
                parsed = json.loads(value.strip())
            elif value.strip().startswith('.'):
                parsed = value.strip()[1:]
            else:
                raise ValueError((name, value))
            result[case] = parsed
    return result


def identifiers(block):
    header = block[:block.index('    var id:')]
    return re.findall(r'(\w+)\s*=\s*"([^"]+)"', header)


def catalog(name, fields, landscape=False):
    block = enum(name)
    props = {field: property_cases(block, field) for field in fields}
    items = []
    for case, id_ in identifiers(block):
        item = {'id': id_, 'name': case, 'kind': 'landscape' if landscape else 'pose'}
        for field, values in props.items():
            if case not in values and '_default' not in values:
                raise ValueError(f'{name}.{case}: missing {field}')
            item[field] = values.get(case, values.get('_default'))
        if not landscape:
            prefixes = [('CP', 'couples'), ('FA', 'family'), ('GR', 'graduation'),
                        ('MT', 'maternity'), ('NB', 'newborn'), ('PR', 'professional'),
                        ('WE', 'weddingEngagement'), ('G', 'friendsGroups'), ('K', 'kids'),
                        ('M', 'masculine'), ('F', 'feminine')]
            item['package'] = next(v for p, v in prefixes if id_.startswith(p))
            item['recipient'] = ('Couple' if item['package'] in ('couples', 'weddingEngagement') or case.startswith('maternityHusband')
                                 else 'Group' if item['package'] == 'friendsGroups'
                                 else 'Family' if item['package'] == 'family'
                                 else 'Caregiver' if item['package'] == 'newborn'
                                 else 'Children' if case == 'kidsSiblingSideHug'
                                 else 'Child' if item['package'] == 'kids' else 'Subject')
            conflicts = ['body_too_square', 'body_too_profile', 'arms_flat_against_body', 'arm_hidden']
            if case in ('overShoulder', 'lookAwayMasculine', 'graduationOverShoulder', 'maternitySideProfile', 'kidsPeekAround', 'weddingProposalReaction'):
                conflicts += ['face_missing', 'face_too_profile', 'face_turned_away']
            if item['category'] == 'moving': conflicts += ['camera_unstable']
            if item['category'] == 'seated': conflicts += ['feet_cropped']
            item['conflicts'] = conflicts
        else:
            item['recipient'] = 'Photographer'
            item['conflicts'] = []
        asset = ROOT / 'DaliCamera/Assets.xcassets' / (item['exampleAssetName'] + '.imageset')
        files = list(asset.glob('*.jpg'))
        if len(files) != 1:
            raise ValueError(f'Invalid asset: {asset}')
        item['asset'] = 'assets/catalog/' + files[0].name
        image_bytes = files[0].read_bytes()
        item['sourceAssetSha256'] = hashlib.sha256(image_bytes).hexdigest()
        if export_check:
            image_bytes = (ROOT / 'apps/dali_camera' / item['asset']).read_bytes()
        elif len(image_bytes) >= 100000:
            image = ImageOps.exif_transpose(Image.open(files[0])).convert('RGB')
            image.thumbnail((720, 720))
            for quality in range(90, 29, -5):
                buffer = io.BytesIO()
                image.save(buffer, format='JPEG', quality=quality, optimize=True)
                image_bytes = buffer.getvalue()
                if len(image_bytes) < 95000: break
        item['assetSha256'] = hashlib.sha256(image_bytes).hexdigest()
        item['_bytes'] = image_bytes
        items.append(item)
    return items


def main():
    global export_check
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    export_check = args.check
    poses = catalog('GuidedPose', ['title', 'cues', 'category', 'setting', 'recommendedCameraAngle', 'recommendedLighting', 'exampleAssetName'])
    landscapes = catalog('LandscapeCompositionRecipe', ['package', 'title', 'cues', 'recommendedCameraAngle', 'recommendedLight', 'safetyNote', 'exampleAssetName'], True)
    assert len(poses) == 76 and len(landscapes) == 24
    asset_bytes = {item['asset']: item.pop('_bytes') for item in poses + landscapes}
    data = {'schemaVersion': 1, 'sourceSha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
            'posePackages': property_cases(enum('GuidedPoseCollectionID'), 'title'),
            'landscapePackages': property_cases(enum('LandscapeCompositionPackageID'), 'title'),
            'angles': {key: {'title': value, 'instruction': property_cases(enum('CameraAngleChoice'), 'instruction')[key]}
                       for key, value in property_cases(enum('CameraAngleChoice'), 'title').items()},
            'poseLighting': {key: {'title': value, 'instruction': property_cases(enum('PoseLightingRecommendation'), 'instruction')[key]}
                             for key, value in property_cases(enum('PoseLightingRecommendation'), 'title').items()},
            'landscapeLighting': {key: {'title': value, 'instruction': property_cases(enum('LandscapeLightRecommendation'), 'instruction')[key]}
                                  for key, value in property_cases(enum('LandscapeLightRecommendation'), 'title').items()},
            'items': poses + landscapes}
    serialized = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    target = ROOT / 'packages/dali_camera_core/lib/src/catalog_data.dart'
    dart = '// Generated by tools/export_shared_catalog.py. Do not edit.\nconst sharedCatalogJson = r\'\'\'\n' + serialized + "''' ;\n"
    manifest = ROOT / 'fixtures/catalog.json'
    if args.check:
        assert target.read_text(encoding='utf-8') == dart, 'Dart catalog drift; run exporter'
        assert manifest.read_text(encoding='utf-8') == serialized, 'Manifest drift'
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(dart, encoding='utf-8')
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(serialized, encoding='utf-8')
    for item in data['items']:
        target_asset = ROOT / 'apps/dali_camera' / item['asset']
        if args.check:
            assert hashlib.sha256(target_asset.read_bytes()).hexdigest() == item['assetSha256'], item['asset']
        else:
            target_asset.parent.mkdir(parents=True, exist_ok=True)
            target_asset.write_bytes(asset_bytes[item['asset']])
    print('Validated 76 poses, 11 pose packages, 24 landscapes, 4 landscape packages and 100 assets')


if __name__ == '__main__':
    main()
