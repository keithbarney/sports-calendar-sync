#!/usr/bin/env python3
"""Compose selected Sports six-benefit sets from verified native captures.
Stage and inspect first, then publish with a visual-review.json whose hashes match.
"""
import argparse
import copy
import importlib.util
import os
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('base', REPO / 'scripts/compose-marketing.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
SCREENS = [(11, 'calendar', 'Sync matches\nto your calendar.'),
           (2, 'team-detail', 'Your teams.\nAll their competitions.'),
           (10, 'broadcasts', 'Know where\nto watch.'),
           (7, 'reminder', 'Get reminders\nbefore kickoff.'),
           (1, 'following', 'All your favorites\nin one place.'),
           (8, 'appearance', 'Light or dark.\nMake it yours.')]
base.SCREENS = SCREENS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--variants', default='iphone/light,iphone/dark,ipad/light,ipad/dark')
    parser.add_argument('--screens', default=','.join(s for _, s, _ in SCREENS))
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    variants = base.selection(args.variants, ['iphone/light', 'iphone/dark', 'ipad/light', 'ipad/dark'])
    selected = base.selection(args.screens, [s for _, s, _ in SCREENS])
    root = REPO / 'screenshots'
    source = args.source_root.resolve()
    assert source != root.resolve(), 'Marketing cards cannot serve as native inputs'
    raw = base.read_json(source / 'manifest.json')['images']
    stage = args.stage or Path(tempfile.mkdtemp(prefix='sports-benefits-review-'))
    assert stage.resolve() != root.resolve(), 'Stage separately from maintained outputs'
    metadata = base.read_json(root / 'manifest.json')
    now = datetime.now(timezone.utc).isoformat()
    renderer = base.SKILL / 'scripts/render_marketing.swift'
    dual = REPO / 'scripts/render-appearance-marketing.swift'
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH='/tmp/app-store-template-module-cache')

    def native(key):
        entry = raw[key]
        file = source / key
        device, appearance, _ = key.split('/')
        expected = base.GEOMETRY[device]
        assert entry.get('kind') != 'marketing' and not entry.get('composition') and not entry.get('marketing'), key
        assert entry.get('capture') and base.digest(file) == entry['sha256'], key
        assert entry['device'] == device and entry['appearance'] == appearance, key
        with Image.open(file) as image:
            assert image.size == (expected['width'], expected['height']), key
            image.verify()
        return file, entry

    # Preflight the whole requested matrix before composing or publishing.
    for variant in variants:
        device, appearance = variant.split('/')
        for number, slug, _ in SCREENS:
            if slug not in selected:
                continue
            if slug == 'appearance':
                for mode in ['light', 'dark']:
                    native(f'{device}/{mode}/1-{device}-{mode}-following.png')
            else:
                native(f'{variant}/{number}-{device}-{appearance}-{slug}.png')

    spec = importlib.util.spec_from_file_location('validation', base.SKILL / 'scripts/validate_screenshots.py')
    validation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validation)
    outputs, changed, retired, reports = [], [], [], {}
    for variant in variants:
        device, appearance = variant.split('/')
        geometry = base.GEOMETRY[device]
        folder = stage / variant
        folder.mkdir(parents=True, exist_ok=True)
        variant_outputs = []
        for number, slug, headline in SCREENS:
            key = f'{variant}/{number}-{device}-{appearance}-{slug}.png'
            dest = stage / key
            variant_outputs.append(key)
            outputs.append(key)
            if slug not in selected:
                assert metadata['images'][key]['kind'] == 'marketing' and base.digest(root / key) == metadata['images'][key]['sha256']
                shutil.copy2(root / key, dest)
                continue
            work = stage / 'inputs' / variant / slug
            work.mkdir(parents=True, exist_ok=True)
            if slug == 'appearance':
                # Render both appearances from this run's native captures; a
                # maintained Light card may still belong to the previous run.
                source_records = []
                for mode in ['light', 'dark']:
                    file, entry = native(f'{device}/{mode}/1-{device}-{mode}-following.png')
                    shutil.copy2(file, work / f'{mode}.png')
                    source_records.append(copy.deepcopy(entry))
                subprocess.run(['swift', str(dual), str(work), device], env=env, check=True, stdout=subprocess.DEVNULL)
                shutil.copy2(work / f'8-{device}-light-appearance.png', dest)
                comparison = (dict(light=[165, 724], dark=[653, 1012], screenshotWidth=1230, frameWidth=16, cornerRadius=48)
                              if device == 'ipad' else dict(light=[105, 790], dark=[455, 1150], screenshotWidth=760, frameWidth=9, cornerRadius=58))
                extra = dict(sourceCaptures=source_records, rendererSha256=base.digest(dual),
                             configuration=dict(width=geometry['width'], height=geometry['height'], headlineSize=geometry['headlineSize'], darkInFront=True, labels=False, **comparison))
            else:
                file, entry = native(key)
                shutil.copy2(file, work / 'native.png')
                config = dict(geometry, headline=headline, headlineWeight='semibold', source='native.png', output='marketing.png')
                base.write_json(work / 'config.json', config)
                subprocess.run(['swift', str(renderer), str(work / 'config.json')], env=env, check=True, stdout=subprocess.DEVNULL)
                shutil.copy2(work / 'marketing.png', dest)
                extra = dict(sourceCapture=copy.deepcopy(entry['capture']), nativeSourceRecord=copy.deepcopy(entry),
                             sourceSha256=base.digest(file), rendererSha256=base.digest(renderer), configuration=config)
            metadata['images'][key] = dict(kind='marketing', templateVersion='v1', headline=headline, composedAt=now,
                                          sha256=base.digest(dest), dimensions=[geometry['width'], geometry['height']],
                                          device=device, appearance=appearance, screen_number=number, screen=slug,
                                          sourceManifest=str(source / 'manifest.json'), **extra)
            changed.append(key)
        expected_names = {Path(key).name for key in variant_outputs}
        assert {file.name for file in folder.glob('*.png')} == expected_names, 'Unexpected files in staging'
        report = validation.validate(folder, 'iphone-6.9' if device == 'iphone' else 'ipad-13')
        assert report['valid'] and len(report['images']) == 6, report
        report.update(validatedAt=now, specifications_checked='2026-09-12', requestedCombination=variant,
                      visualReview=dict(passed=False, status='awaiting visual inspection'))
        reports[variant] = report
        base.contact_sheet(folder, device, appearance, stage / f'contact-sheet-{device}-{appearance}.jpg')
        metadata[f'store_selection_{device}_{appearance}'] = variant_outputs
        metadata.setdefault('marketingRevisions', {})[variant] = dict(date=now, scope='selected', screens=selected,
            status='ready-for-user-review', data='Fictional broadcast listings and manually seeded local Apple Calendar demo; not a live sync test.', uploadPerformed=False)
        for key in list(metadata['images']):
            if key.startswith(variant + '/') and key not in variant_outputs:
                metadata.setdefault('retiredImageRecords', {})[key] = metadata['images'].pop(key)
                retired.append(key)
    if args.publish:
        review = base.read_json(stage / 'visual-review.json')
        assert review['passed'] and review['hashes'] == {key:base.digest(stage / key) for key in outputs}, 'Images changed after visual review'
        for variant, report in reports.items():
            report['visualReview'] = review
            report['folder'] = str(root / variant)
        # Every requested combination and its visual-review hash passed before mutation.
        for key in changed:
            (root / key).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(stage / key, root / key)
        for key in retired:
            (root / key).unlink(missing_ok=True)
    for variant, report in reports.items():
        device, appearance = variant.split('/')
        name = f'validation-{device}-{appearance}.json'
        base.write_json(stage / name, report)
        if args.publish:
            shutil.copy2(stage / name, root / name)
            name = f'contact-sheet-{device}-{appearance}.jpg'
            shutil.copy2(stage / name, root / name)
    base.write_json(stage / 'manifest.json', metadata)
    if args.publish:
        shutil.copy2(stage / 'manifest.json', root / 'manifest.json')
    print(f'{"Published" if args.publish else "Staged"} {len(changed)} cards across {len(variants)} sets: {stage}')


if __name__ == '__main__':
    main()
