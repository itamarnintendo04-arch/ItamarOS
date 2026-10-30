'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const ROOT=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const exists=p=>fs.existsSync(path.join(ROOT,p));
const platformManifest=JSON.parse(read('updates/native-apps.json'));
assert.equal(platformManifest.version,'1.3.0');
assert.equal(platformManifest.signedBinariesPublished,false);
assert.equal(platformManifest.components.length,8);
for(const component of platformManifest.components) {
 if(['itamaros-android','itamaros-android-tv'].includes(component.id)) {
  if(component.releaseStatus==='unverified-debug-preview') {
   assert.match(component.package,/^https:\/\/github\.com\/itamarnintendo04-arch\/ItamarOS\/releases\/download\/v1\.3-android-preview\/ItamarOS-Android-1\.3\.0-debug\.apk$/);
  } else {
   assert.equal(component.releaseStatus,'source-only');
   assert.equal(component.package,null,'Never advertise an unpublished Android APK');
  }
 } else {
  assert.equal(component.package,null,'Unpublished native platforms must not invent binary downloads: '+component.id);
 }
}

const appleRoot='native-apps/apple';
const androidRoot='native-apps/android';
const project=read(appleRoot+'/project.yml');
for(const name of ['ItamarOSiOS','ItamarOStvOS','ItamarOSmacOS','ItamarOSvisionOS','ItamarOSwatchOS']) {
 assert.ok(project.includes(name+':'),name+' project target missing');
}
for(const x of ['Shared/ItamarOSApp.swift','Shared/NativeGameView.swift','Shared/MainScreen.swift','Shared/NativeSettingsView.swift','Shared/TVStreamingView.swift','Shared/LocalMediaView.swift','Shared/IPAImportView.swift','Watch/WatchApp.swift']){
 assert.ok(exists(appleRoot+'/'+x),x);
 assert.doesNotMatch(read(appleRoot+'/'+x),/\bWKWebView\b|\bUIWebView\b|\bSFSafariViewController\b/,'Native Apple app must not be a website wrapper');
}
const nativeMedia=read(appleRoot+'/Shared/LocalMediaView.swift');
assert.match(nativeMedia,/PhotosPicker\(/,'iOS player must allow choosing media from Photos');
assert.match(nativeMedia,/\.image, \.movie, \.audio/,'Apple Files picker must allow image, video and audio');
assert.match(nativeMedia,/VideoPlayer\(/,'Apple video playback should use AVKit');
const appleSignIn=read(appleRoot+'/Shared/AppleAccountSignInView.swift');
assert.match(appleSignIn,/SignInWithAppleButton/,'Apple sign-in uses AuthenticationServices');
assert.match(appleSignIn,/ASAuthorizationAppleIDCredential/,'Apple sign-in requires genuine system authorization');
assert.match(appleSignIn,/static let limit = 5/,'At most five local Apple profile slots');
assert.match(appleSignIn,/kSecAttrAccessibleWhenUnlockedThisDeviceOnly/,'Account identifiers must remain in this device Keychain');
assert.match(appleSignIn,/SecItemCopyMatching|SecItemUpdate/,'Profiles need persistent local Keychain storage');
assert.match(appleSignIn,/func logOut\(\)/,'Users can sign out locally');
assert.match(appleSignIn,/func remove\(_ identifier: String\)/,'Users can remove saved profiles');
assert.match(appleSignIn,/func activate\(_ identifier: String\)/,'Users can select authorized profiles');
assert.match(appleSignIn,/getCredentialState/,'Selected Apple identities must be checked with Apple');
assert.doesNotMatch(appleSignIn,/SecItemSynchronizable|\.identityToken\b|\.authorizationCode\b|URLSession|URLRequest|SecureField\(/,'No password collection, server requests, or cloud-synced profiles');

assert.doesNotMatch(appleSignIn,/SecureField\(|URLSession|URLRequest|\.identityToken\b|\.authorizationCode\b/,'Sign-in must not capture passwords or transmit Apple authorization tokens');
assert.match(read(appleRoot+'/project.yml'),/CODE_SIGN_ENTITLEMENTS/,'Apple sign-in entitlement should be declared');
assert.ok(exists(appleRoot+'/iOS/ItamarOS.entitlements'),'Sign in with Apple capability file should be present');
const ipaImport=read(appleRoot+'/Shared/IPAImportView.swift');
assert.match(ipaImport,/#if os\(iOS\)/,'IPA file workflow should be iOS only');
assert.match(ipaImport,/\.fileImporter\(/,'Choose IPA from the official Files picker');
assert.match(ipaImport,/ShareLink\(/,'User must explicitly share IPA with a tool they choose');
assert.doesNotMatch(ipaImport,/URLSession|http\.post|privateKey|password|\.install\(/i,'Do not secretly upload, sign or install user IPAs');
assert.match(read(appleRoot+'/Shared/MainScreen.swift'),/IPAImportView\(\)/,'IPA tab should be accessible in iPhone app');
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
const androidMedia=read(androidRoot+'/app/src/main/java/org/itamaros/nativeapp/NativeMediaPreview.kt');
assert.match(androidMedia,/ImageView/,'Android preview must support images');
assert.match(androidMedia,/VideoView/,'Android preview must support video');
assert.match(androidMedia,/MediaPlayer/,'Android preview must support audio');
assert.match(androidManifest,/android\.permission\.REQUEST_INSTALL_PACKAGES/,'APK installer declares the Android install-request permission');
const androidActivity=read(androidRoot+'/app/src/main/java/org/itamaros/nativeapp/MainActivity.kt');
const androidScreen=read(androidRoot+'/app/src/main/java/org/itamaros/nativeapp/NativeScreen.kt');
assert.ok(androidActivity.includes('ActivityResultContracts.OpenDocumentTree'),'External storage chooser should use SAF');
assert.ok(androidActivity.includes('DocumentsContract.createDocument'),'External backup requires explicit folder grant');
assert.ok(androidActivity.includes('Settings.ACTION_APPLICATION_DETAILS_SETTINGS'),'App movement settings controlled by Android');
assert.ok(androidActivity.includes('getLeanbackLaunchIntentForPackage'),'Native Android TV launch');
assert.ok(androidActivity.includes('ActivityResultContracts.PickVisualMedia'),'Photos picker must use Android system picker');
assert.ok(androidActivity.includes('Intent.ACTION_INSTALL_PACKAGE'),'APK installer should use Android system confirmation');
assert.ok(androidActivity.includes('Intent.FLAG_GRANT_READ_URI_PERMISSION'),'Installer must be granted narrow APK URI access');

assert.ok(androidMedia.includes('AndroidView(')&&androidMedia.includes('VideoView('),'Real native media player, not embedded website');
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

const windowsRoot='native-apps/windows';
for(const file of ['ItamarOS.Native.Windows.csproj','App.xaml','App.xaml.cs','MainWindow.xaml','MainWindow.xaml.cs','Assets/itamaros-logo.png','Assets/itamaros-icon.ico']){
 assert.ok(exists(windowsRoot+'/'+file), 'Missing native Windows WPF source or branding: '+file);
}
assert.doesNotMatch(read(windowsRoot+'/MainWindow.xaml.cs'),/\bnew\s+(?:WebView2?|WebBrowser)\s*\(|\bMicrosoft\.Web\.WebView2\b/,'WPF code must not construct an embedded web browser');
assert.match(read(windowsRoot+'/MainWindow.xaml.cs'),/private void UpdateTaskbar\(\)/);
assert.match(read(windowsRoot+'/MainWindow.xaml.cs'),/private FrameworkElement CreateSettings\(\)/);
console.log('Native Windows WPF source and branding checks passed.');
