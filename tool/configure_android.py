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
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>\n'
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
            '    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>\n'
            '    <application'
        )
        if 'android.permission.INTERNET' not in content:
            content = content.replace('<application', perm_block)

        service_tag = '''
        <!-- Flutter Foreground Service: Runs continuously while app is in Recents or locked, stops when swiped away from Recents -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="mediaPlayback|dataSync"
            android:stopWithTask="true"
            android:exported="false" />
        '''
        if 'com.pravera.flutter_foreground_task' not in content:
            content = content.replace('</application>', service_tag + '\n    </application>')
        else:
            # Ensure android:stopWithTask="true" is present
            content = content.replace('android:exported="false" />', 'android:stopWithTask="true"\n            android:exported="false" />')

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
        print("Updated AndroidManifest.xml successfully with stopWithTask Foreground Service.")

    # 2. gradle-wrapper.properties (Update to Gradle 8.4)
    gradle_wrapper = 'android/gradle/wrapper/gradle-wrapper.properties'
    if os.path.exists(gradle_wrapper):
        with open(gradle_wrapper, 'r', encoding='utf-8') as f:
            gw = f.read()
        gw = re.sub(r'distributionUrl=.*', r'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.4-all.zip', gw)
        with open(gradle_wrapper, 'w', encoding='utf-8') as f:
            f.write(gw)
        print("Updated gradle-wrapper.properties with Gradle 8.4.")

    # 3. settings.gradle
    settings_gradle = 'android/settings.gradle'
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r', encoding='utf-8') as f:
            s = f.read()
        
        plugins_block = '''
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.24" apply false
}
'''
        if 'plugins {' in s:
            s = re.sub(r'plugins\s*\{[^}]*\}', plugins_block.strip(), s)
        else:
            s = s + '\n' + plugins_block

        with open(settings_gradle, 'w', encoding='utf-8') as f:
            f.write(s)
        print("Updated settings.gradle with Kotlin 1.9.24.")

    # 4. build.gradle
    build_gradle = 'android/build.gradle'
    if os.path.exists(build_gradle):
        with open(build_gradle, 'r', encoding='utf-8') as f:
            b = f.read()

        buildscript_block = '''buildscript {
    ext.kotlin_version = '1.9.24'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.3.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
'''
        if 'buildscript {' not in b:
            b = buildscript_block + '\n' + b

        with open(build_gradle, 'w', encoding='utf-8') as f:
            f.write(b)
        print("Updated build.gradle with Kotlin buildscript classpath.")

    # 5. app/build.gradle (Set Java & Kotlin JVM target to 17)
    app_build_gradle = 'android/app/build.gradle'
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r', encoding='utf-8') as f:
            ab = f.read()
        ab = ab.replace('JavaVersion.VERSION_1_8', 'JavaVersion.VERSION_17')
        ab = ab.replace("jvmTarget = '1.8'", "jvmTarget = '17'")
        ab = ab.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 21')
        ab = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 21', ab)
        with open(app_build_gradle, 'w', encoding='utf-8') as f:
            f.write(ab)
        print("Updated app/build.gradle with Java 17 and Kotlin 17 JVM targets.")

if __name__ == '__main__':
    configure_android()
