import os
import re

def configure_android():
    # 1. AndroidManifest.xml
    manifest_path = 'android/app/src/main/AndroidManifest.xml'
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = content.replace('android:label="spotiloop"', 'android:label="Spoti Loop"')
        content = content.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')

        perm_block = (
            '<uses-permission android:name="android.permission.INTERNET"/>\n'
            '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n'
            '    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n'
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n'
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n'
            '    <application'
        )
        if 'android.permission.INTERNET' not in content:
            content = content.replace('<application', perm_block)

        deep_link = '''
              <!-- Spotify OAuth PKCE Deep Link Callback -->
              <intent-filter>
                  <action android:name="android.intent.action.VIEW"/>
                  <category android:name="android.intent.category.DEFAULT"/>
                  <category android:name="android.intent.category.BROWSABLE"/>
                  <data android:scheme="spotiloop" android:host="callback"/>
                  <data android:scheme="spotiloop"/>
              </intent-filter>
        '''
        if 'android:scheme="spotiloop"' not in content:
            content = content.replace('</activity>', deep_link + '\n        </activity>')

        with open(manifest_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Updated AndroidManifest.xml successfully.")

    # 2. settings.gradle
    settings_gradle = 'android/settings.gradle'
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r', encoding='utf-8') as f:
            s = f.read()
        s = re.sub(r'id "org\.jetbrains\.kotlin\.android" version "[^"]+"', 'id "org.jetbrains.kotlin.android" version "1.9.24"', s)
        with open(settings_gradle, 'w', encoding='utf-8') as f:
            f.write(s)
        print("Updated settings.gradle with Kotlin 1.9.24.")

    # 3. build.gradle
    build_gradle = 'android/build.gradle'
    if os.path.exists(build_gradle):
        with open(build_gradle, 'r', encoding='utf-8') as f:
            b = f.read()
        b = re.sub(r"ext\.kotlin_version = '[^']+'", "ext.kotlin_version = '1.9.24'", b)
        with open(build_gradle, 'w', encoding='utf-8') as f:
            f.write(b)
        print("Updated android/build.gradle with Kotlin 1.9.24.")

    # 4. app/build.gradle
    app_build_gradle = 'android/app/build.gradle'
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r', encoding='utf-8') as f:
            ab = f.read()
        ab = ab.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 21')
        with open(app_build_gradle, 'w', encoding='utf-8') as f:
            f.write(ab)
        print("Updated app/build.gradle with minSdkVersion 21.")

if __name__ == '__main__':
    configure_android()
