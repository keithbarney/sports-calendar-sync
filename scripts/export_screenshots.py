#!/usr/bin/env python3
"""Export named XCTest attachments without resizing; require complete screen coverage."""
import argparse, hashlib, importlib.util, json, plistlib, shutil, subprocess
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image, ImageDraw

NAMES = ['01-following','02-team-detail','03-manage-competitions','04-discover','05-competition-filter','06-settings','07-reminder','08-appearance','09-empty-following','10-broadcasts']
STORE = ['01-following','02-team-detail','03-manage-competitions','04-discover','06-settings']
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--screens',default='following,team-detail,broadcasts,reminder')
p.add_argument('run',type=Path);p.add_argument('--app',type=Path,required=True);p.add_argument('--udid',required=True)
p.add_argument('--device',choices=['iphone','ipad'],required=True)
p.add_argument('--appearance',choices=['light','dark'],required=True)
p.add_argument('--display',choices=['iphone-6.9','ipad-13'],required=True)
p.add_argument('--output-root',type=Path,default=Path('/Users/keithbarney/Documents/Github/sports-calendar-sync/screenshots'))
a=p.parse_args();requested=a.screens.split(',');assert set(requested).issubset({n[3:] for n in NAMES});NAMES=[n for n in NAMES if n[3:] in requested];STORE=list(NAMES);root=Path(__file__).resolve().parents[1];run=a.run.resolve()
attachments=run/'attachments'
all_dir=run/f'all-screens/en-US/{a.display}/{a.appearance}';store_dir=run/f'store/en-US/{a.display}/{a.appearance}'
all_dir.mkdir(parents=True);store_dir.mkdir(parents=True)
rows=json.loads((attachments/'manifest.json').read_text());found={}
expected_sizes={'iphone':{(1320,2868)},'ipad':{(2064,2752),(2048,2732)}}[a.device]
actual_size=None
for row in rows:
 for item in row['attachments']:
  name=item['suggestedHumanReadableName'].split('_')[0]
  if name in NAMES:
   assert name not in found, f'Duplicate attachment: {name}'
   assert item['deviceId']==a.udid and not item['isAssociatedWithFailure'],item
   found[name]=item
assert set(found)==set(NAMES), f'Missing screens: {set(NAMES)-set(found)}'
for name in NAMES:
 with Image.open(attachments/found[name]['exportedFileName']) as im:
  assert im.size in expected_sizes,f'Unexpected native size: {im.size}; expected one of {expected_sizes}'
  actual_size=im.size
  im.convert('RGB').save(all_dir/(name+'.png'))
for order,name in enumerate(STORE,1):shutil.copyfile(all_dir/(name+'.png'),store_dir/(f'{order:02d}-'+name[3:]+'.png'))
validator=Path.home()/'.codex/skills/ios-app-store-screenshots/scripts/validate_screenshots.py'
spec=importlib.util.spec_from_file_location('validator',validator);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
report=module.validate(store_dir,a.display);(run/'validator.json').write_text(json.dumps(report,indent=2));assert report['valid'],report['errors']
thumb_height=round(330*actual_size[1]/actual_size[0]);cell_height=thumb_height+30
sheet=Image.new('RGB',(3*330,((len(NAMES)+2)//3)*cell_height),'#eeeeee');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(NAMES):
 with Image.open(all_dir/(name+'.png')) as im:
  im.thumbnail((330,thumb_height));x=(i%3)*330;y=(i//3)*cell_height;sheet.paste(im,(x,y));draw.text((x+8,y+thumb_height+4),name,fill='black')
sheet.save(run/'contact-sheet.jpg',quality=90)
def git(*args):return subprocess.check_output(['git',*args],cwd=root).decode().strip()
with (a.app/'Info.plist').open('rb') as f:info=plistlib.load(f)
source_files=sorted(set(git('ls-files').splitlines()+git('ls-files','--others','--exclude-standard').splitlines()))
source_hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in source_files if (root/name).is_file()}
hashes={str(f.relative_to(run)):hashlib.sha256(f.read_bytes()).hexdigest() for folder in [all_dir,store_dir] for f in sorted(folder.glob('*.png'))}
(run/'hashes.txt').write_text(''.join(f'{digest}  {name}\n' for name,digest in hashes.items()))
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))['devices']
runtime,device=next((rt,d) for rt,ds in devices.items() for d in ds if d['udid']==a.udid)
manifest={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':git('rev-parse','HEAD'),'working_changes':git('status','--short'),'source_sha256':source_hashes,'bundle':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'configuration':'Debug','release_ui_difference':'Debug-only isolated mock fixtures; review header/picker hidden by screenshot mode. Production layout retained.','simulator':device['name'],'udid':a.udid,'runtime':runtime,'dimensions':list(actual_size),'locale':'en-US','device':a.device,'appearance':a.appearance,'data':'App-owned fictional in-memory fixtures, no live service writes','clock':'Start of capture day; league +5, domestic cup +10, continental +15 days; status bar 9:41','coverage':NAMES,'store_selection':STORE,'omissions':'Core selection only; connected permissions simulated; external writes blocked.','hashes':hashes,'validation':report['valid'],'upload':'Not requested; no upload performed'}
(run/'manifest.json').write_text(json.dumps(manifest,indent=2))
output=a.output_root.resolve()
current_path=output/'manifest.json'
current=json.loads(current_path.read_text()) if current_path.exists() else {'images':{}}
current.setdefault('images',{})
target=output/a.device/a.appearance;target.mkdir(parents=True,exist_ok=True)
published={name:f'{a.device}/{a.appearance}/{int(name[:2])}-{a.device}-{a.appearance}-{name[3:]}.png' for name in NAMES}
provenance={key:value for key,value in manifest.items() if key not in ['source_sha256','hashes','coverage','store_selection']}
provenance['source_fingerprint']=hashlib.sha256(json.dumps(source_hashes,sort_keys=True).encode()).hexdigest()
for name,relative in published.items():
 source=all_dir/(name+'.png');destination=output/relative
 temporary=destination.with_suffix('.pending')
 shutil.copyfile(source,temporary);temporary.replace(destination)
 current['images'][relative]={'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'dimensions':list(actual_size),'device':a.device,'appearance':a.appearance,'screen_number':int(name[:2]),'screen':name[3:],'capture':dict(provenance, resultBundle=str(run/'capture.xcresult'), attachmentFile=found[name]['exportedFileName'], attachmentName=found[name]['suggestedHumanReadableName'], capturedAt=datetime.fromtimestamp(found[name]['timestamp'],timezone.utc).isoformat())}
current.setdefault('last_captures',{})[f'{a.device}_{a.appearance}']=manifest
current[f'store_selection_{a.device}_{a.appearance}']=[published[name] for name in STORE]
current_path.write_text(json.dumps(current,indent=2)+'\n')
shutil.copyfile(run/'contact-sheet.jpg',output/f'contact-sheet-{a.device}-{a.appearance}.jpg')
report['canonical_paths']=[published[name] for name in STORE]
(output/f'validation-{a.device}-{a.appearance}.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'screens':len(NAMES),'store_screens':len(STORE),'valid':True,'output':str(target)},indent=2))
