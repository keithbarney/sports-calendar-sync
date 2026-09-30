#!/usr/bin/env python3
"""Record visually verified native system Calendar captures in a staging manifest.
Use only after inspecting the separate, simulator-local Sports demo calendar.
"""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-root', type=Path, required=True)
parser.add_argument('--variants', required=True)
parser.add_argument('--fixture-date', required=True)
parser.add_argument('--helper-source', type=Path, required=True)
args = parser.parse_args()
root = args.source_root
path = root / 'manifest.json'
manifest = json.loads(path.read_text())
for variant in args.variants.split(','):
    device, appearance = variant.split('/')
    assert device in ['iphone','ipad'] and appearance in ['light','dark']
    key = f'{variant}/11-{device}-{appearance}-calendar.png'
    native = root / key
    captured = datetime.fromtimestamp(native.stat().st_mtime, timezone.utc).isoformat()
    with Image.open(native) as image:
        expected = (1320, 2868) if device == 'iphone' else (2048, 2732)
        assert image.size == expected
        image.convert('RGB').save(native)
    app = manifest['images'][f'{variant}/1-{device}-{appearance}-following.png']['capture']
    capture = {k: app[k] for k in ['simulator','udid','runtime','locale']}
    capture.update(bundle='com.apple.mobilecal', version='iOS 26.5 system Calendar', build='23F77',
                   capturedAt=captured, nativeFile=str(native.resolve()), appearance=appearance,
                   method='simctl native screenshot after Simulator visual inspection',
                   fixtureDate=args.fixture_date,
                   helperSource=str(args.helper_source.resolve()),
                   helperSourceSha256=hashlib.sha256(args.helper_source.read_bytes()).hexdigest(),
                   data='Four manually staged fictional fixtures in the simulator-local Sports calendar. Cloud writes refused. Not evidence of live app sync.',
                   visualChecks=['Four demo fixtures visible','Actual requested appearance','No permission prompts or demo-helper breadcrumb'])
    manifest['images'][key] = dict(kind='raw', sha256=hashlib.sha256(native.read_bytes()).hexdigest(),
                                  dimensions=list(expected), device=device, appearance=appearance,
                                  screen_number=11, screen='calendar', capture=capture)
path.write_text(json.dumps(manifest, indent=2)+'\n')
print('Registered verified native Calendar inputs.')
