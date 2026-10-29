'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const ROOT=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const exists=p=>fs.existsSync(path.join(ROOT,p));
const platformManifest=JSON.parse(read('updates/native-apps.json'));
assert.equal(platformManifest.version,'1.1.0');
assert.equal(platformManifest.status,'source-only');
assert.equal(platformManifest.signedBinariesPublished,false);
assert.equal(platformManifest.components.length,7);
assert.ok(platformManifest.components.every(c=>c.package===null),'Do not invent native downloadable binaries');

const appleRoot='native-apps/apple';
const androidRoot='native-apps/android';
const project=read(appleRoot+'/project.yml');
for(const name of ['ItamarOSiOS','ItamarOStvOS','ItamarOSmacOS','ItamarOSvisionOS','ItamarOSwatchOS']) {
 assert.ok(project.includes(name+':'),name+' project target missing');
}
for(const x of ['Shared/ItamarOSApp.swift','Shared/NativeGameView.swift','Shared/MainScreen.swift','Shared/NativeSettingsView.swift','Shared/TVStreamingView.swift','Shared/LocalMediaView.swift','Watch/WatchApp.swift']){
 assert.ok(exists(appleRoot+'/'+x),x);
 assert.doesNotMatch(read(appleRoot+'/'+x),/\bWKWebView\b|\bUIWebView\b|\bSFSafariViewController\b/,'Native Apple app must not be a website wrapper');
}
for(const p of ['iOS','tvOS','macOS','visionOS','watchOS']) {
 const assets=appleRoot+'/'+p+'/Assets.xcassets';
 assert.ok(exists(assets+'/AppIcon.appiconset/Contents.json'),p+' appicon metadata');
 assert.ok(exists(assets+'/AppIcon.appiconset/Icon.png'),p+' app icon image');
 assert.ok(exists(assets+'/BrandMark.imageset/Logo.png'),p+' brand mark');
}
const androidManifest=read(androidRoot+'/app/src/main/AndroidManifest.xml');
assert.match(androidManifest,/<manifest[^>]*android:installLocation="auto"/);
assert.doesNotMatch(androidManifest,/<application[^>]*android:installLocation/);
assert.match(androidManifest,/android.intent.category.LEANBACK_LAUNCHER/);
assert.match(androidManifest,/android.hardware.touchscreen" android:required="false"/);
assert.ok(exists(androidRoot+'/app/src/main/res/drawable-nodpi/itamaros_logo.png'));
assert.ok(exists(androidRoot+'/app/src/main/res/drawable-nodpi/itamaros_tv_banner.png'));
const androidActivity=read(androidRoot+'/app/src/main/java/org/itamaros/nativeapp/MainActivity.kt');
const androidScreen=read(androidRoot+'/app/src/main/java/org/itamaros/nativeapp/NativeScreen.kt');
assert.ok(androidActivity.includes('ActivityResultContracts.OpenDocumentTree'),'External storage chooser should use SAF');
assert.ok(androidActivity.includes('DocumentsContract.createDocument'),'External backup requires explicit folder grant');
assert.ok(androidActivity.includes('Settings.ACTION_APPLICATION_DETAILS_SETTINGS'),'App movement settings controlled by Android');
assert.ok(androidActivity.includes('getLeanbackLaunchIntentForPackage'),'Native Android TV launch');
assert.ok(androidScreen.includes('AndroidView(')&&androidScreen.includes('VideoView('),'Real native media player, not embedded website');
for(const s of [androidActivity,androidScreen])assert.doesNotMatch(s,/\bWebView\b(?=\s*\()/,'Do not initialize an Android WebView');
assert.match(read('native-apps/TV_COMPATIBILITY.md'),/No universal replacement image|no single file/i);

const html=read('index.html');
assert.ok(html.includes('id="taskbar-apps"'));
assert.ok(html.includes('apps/taskbar.js?v=1.1.0'));
assert.ok(html.includes('apps/settings.js?v=1.1.0'));
assert.ok(read('desktop/prepare.cjs').includes('apps/taskbar.js'));
assert.ok(read('desktop/prepare.cjs').includes('apps/settings.js'));
for(const name of ['taskbar','settings'])new vm.Script(read('apps/'+name+'.js'),{filename:name+'.js'});
assert.ok(read('apps/taskbar.js').includes('localStorage.setItem(KEY'));
assert.ok(read('apps/taskbar.js').includes('running.delete(id)'));
assert.ok(read('apps/settings.js').includes("name:'Privacy & Security'"));
assert.ok(read('apps/settings.js').includes("name:'Storage & Files'"));
assert.ok(read('apps/settings.js').includes("name:'Apps & Taskbar'"));
assert.ok(read('apps/settings.js').includes("name:'Accessibility'"));
console.log('ItamarOS native Apple/Android sources, platform branding, taskbar, settings and USB compatibility assertions passed.');
