<img src="assets/images/logo.png" align="right" width="224" height="224" style="margin-left:20px;">

# Embla

Embla is a voice-driven virtual assistant app that uses the Icelandic-language
[Greynir](https://greynir.is) query engine. This is the repository for the
cross-platform Embla mobile client.

The client is implemented in [Dart](https://dart.dev/) using the
[Flutter](https://flutter.dev) framework. Currently built to run on Android SDK 21+,
with iOS, macOS, Windows and web support on the roadmap.

## Build instructions

Building the Embla client requires the Flutter framework:

* [Install Flutter](https://flutter.dev/docs/get-started/install)

Building for iOS requires a recent version of Xcode. Building for Android requires
a recent version of Android Studio.

Clone the repository:

```
$ git clone https://github.com/mideind/Embla
```

Change to the repository root and run the following command:

```
$ flutter run
```

This should launch the app in development mode on your device of choice (e.g.
simulator, attached physical device, etc.).

NB: To work, the app requires a Google Cloud Speech-to-Text API service account configuration.
Once you have acquired a JSON config file via their API console, put it in `assets/keys/gaccount.json`.

## Screenshots

TBD

## Credits

The Embla client uses Google's [Speech-to-Text API](https://cloud.google.com/speech-to-text)
for speech recognition. Speech synthesis is accomplished via voices commissioned by
[Blindrafélagið](https://blind.is), the Icelandic Association of the Visually Impaired.

## GPL License

This program and its source code is &copy; 2020 [Miðeind ehf.](https://miðeind.is) and is
released as open source software under the terms and conditions of the
[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.html).
Alternative licensing arrangements are negotiable.
