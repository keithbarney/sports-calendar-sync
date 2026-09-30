#!/usr/bin/env python3
"""Capture selected native Sports core screens without replacing marketing cards."""
import argparse,os,plistlib,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1];devices={'iphone':'B8CD88B2-D876-49ED-8CB8-303A0C59FEC5','ipad':'017B5198-4197-412E-8FAD-66E1B817324C'}
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--devices',default='iphone,ipad');p.add_argument('--appearances',default='light,dark');p.add_argument('--variants',help='Exact combinations such as iphone/dark,ipad/light,ipad/dark');p.add_argument('--screens',default='following,team-detail,broadcasts,reminder');p.add_argument('--output-root',type=Path,default=os.environ.get('SCREENSHOT_OUTPUT_ROOT'));a=p.parse_args()
def select(value,valid):
 values=value.split(',')
 if not values or len(set(values))!=len(values) or set(values)-set(valid):p.error(f'Invalid selection: {value}')
 return values
selected=select(a.devices,devices);appearances=select(a.appearances,['light','dark']);select(a.screens,['following','team-detail','manage-competitions','discover','settings','reminder','broadcasts'])
variants=select(a.variants,[f'{d}/{v}' for d in selected for v in appearances]) if a.variants else [f'{d}/{v}' for d in selected for v in appearances]
selected=[device for device in selected if any(variant.startswith(device+'/') for variant in variants)]
work=Path(tempfile.mkdtemp(prefix='sports-native-capture-'));output=a.output_root or work/'native'
if output.resolve()==(repo/'screenshots').resolve():p.error('Native sources must not overwrite canonical marketing cards')
output.mkdir(parents=True,exist_ok=True);derived=repo/'build/screenshot-capture';log=work/'capture.log';python=os.environ.get('SCREENSHOT_PYTHON','/Users/keithbarney/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3')
def run(args):
 with log.open('a') as stream:subprocess.run(args,cwd=repo,stdout=stream,stderr=subprocess.STDOUT,check=True)
print(f'Capture evidence retained: {work}',flush=True)
run(['xcodegen','generate']);run(['xcodebuild','-project','SportsCalendarSync.xcodeproj','-scheme','SportsCalendarSyncScreenshots','-configuration','Debug','-destination',f'platform=iOS Simulator,id={devices[selected[0]]}','-derivedDataPath',str(derived),'-parallel-testing-enabled','NO','SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG','build-for-testing'])
products=derived/'Build/Products';original=next(products.glob('SportsCalendarSyncScreenshots_*.xctestrun'));config=products/'MarketingSelected.xctestrun';data=plistlib.loads(original.read_bytes())
try:
 for device in selected:
  udid=devices[device];run(['xcrun','simctl','bootstatus',udid,'-b'])
  run(['xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100'])
  for appearance in appearances:
   if f'{device}/{appearance}' not in variants:continue
   variant=work/f'{device}-{appearance}';variant.mkdir()
   target=data['SportsCalendarSyncScreenshotTests']
   for env in ['EnvironmentVariables','TestingEnvironmentVariables']:target.setdefault(env,{}).update(SCREENSHOT_SCREENS=a.screens,SCREENSHOT_APPEARANCE=appearance.title())
   config.write_bytes(plistlib.dumps(data))
   run(['xcodebuild','test-without-building','-xctestrun',str(config),'-destination',f'platform=iOS Simulator,id={udid}','-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-only-testing:SportsCalendarSyncScreenshotTests/CaptureTests/testCaptureCoreScreens','-resultBundlePath',str(variant/'capture.xcresult')])
   run(['xcrun','xcresulttool','export','attachments','--path',str(variant/'capture.xcresult'),'--output-path',str(variant/'attachments')])
   run([python,str(repo/'scripts/export_screenshots.py'),str(variant),'--app',str(products/'Debug-iphonesimulator/SportsCalendarSync.app'),'--udid',udid,'--device',device,'--appearance',appearance,'--display','iphone-6.9' if device=='iphone' else 'ipad-13','--output-root',str(output),'--screens',a.screens])
   print(f'Captured {device}/{appearance}: {a.screens}',flush=True)
finally:
 config.unlink(missing_ok=True)
 for device in selected:subprocess.run(['xcrun','simctl','status_bar',devices[device],'clear'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 import shutil
 if log.exists():shutil.copy2(log,output/'capture.log')
print(f'Native inputs ready: {output}')
