<img src="assets/images/logo.png" align="right" width="224" height="224" style="margin-left:20px;">

# Embla

Embla is a voice-driven virtual assistant app powered by the Icelandic-language
[Greynir](https://greynir.is) query engine. This is the repository for the
cross-platform Embla mobile client.

The client is implemented in [Dart](https://dart.dev/) using the
[Flutter](https://flutter.dev) framework. Currently built to run on Android 8.0+ (SDK >= 26),
with iOS support on the roadmap.

## Build instructions

Building the Embla client requires the Flutter framework:

* [Install Flutter](https://flutter.dev/docs/get-started/install)

Building for Android requires a recent version of Android Studio. Building for iOS
requires a recent version of Xcode.

Clone the repository:

```
$ git clone https://github.com/mideind/Embla
```

In order to work as intended, the app requires a JSON configuration file containing a key
for Google's Speech-to-Text API. Get this document from Google's API console and and save
it at the following path within the repository:

```keys/gaccount.json```

Then run the following script:

```
$ /bin/bash keys/gen_keysfile.sh
```

You should now be able to build and run the app:

```
$ flutter run
```

This should launch the app in development mode on your device of choice (e.g.
simulator, attached physical device, etc.).

To build an Android `apk` release binary for arm64, run the following script:

```
$ bash build.sh
```

## Screenshots

TBD

## Credits

The Embla client uses [Snowboy](https://github.com/seasalt-ai/snowboy) for hotword
detection and Google's [Speech-to-Text API](https://cloud.google.com/speech-to-text) for
speech recognition. Speech synthesis is accomplished via synthetic voices commissioned by
[Blindrafélagið](https://blind.is), the Icelandic Association of the Visually Impaired.

## License

Embla is Copyright (C) 2021 [Miðeind ehf.](https://mideind.is)

<a href="https://mideind.is"><img src="assets/images/mideind_logo.png" alt="Miðeind ehf." width="214" height="66" align="right" style="margin-left:20px; margin-bottom: 20px;"></a>

This program and its source code is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details.

The full text of the GNU General Public License v3 is
[included here](https://github.com/mideind/PyEmbla/blob/master/LICENSE.txt)
and also available here:
[https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html).

If you wish to use this program in ways that are not covered under the
GNU GPLv3 license, please contact us at [mideind@mideind.is](mailto:mideind@mideind.is)
to negotiate a custom license. This applies for instance if you want to include or use
this software, in part or in full, in other software that is not licensed under
GNU GPLv3 or other compatible licenses.
