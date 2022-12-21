[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Language](https://img.shields.io/badge/language-dart-lightblue)]()
![Release](https://shields.io/github/v/release/mideind/Embla_Flutter?display_name=tag)
![Play Store](https://img.shields.io/endpoint?color=green&logo=google-play&logoColor=green&url=https%3A%2F%2Fplay.cuzi.workers.dev%2Fplay%3Fi%3Dis.mideind.embla%26l%3DPlay%2520Store%26m%3D%24version)
[![Build](https://github.com/mideind/Embla_Flutter/actions/workflows/main.yml/badge.svg)]()

<img src="img/app_icon.png" align="right" width="200" height="200" style="margin-left:20px;">

# Embla Flutter client

Embla is an Icelandic-language voice assistant app powered by the
[Greynir](https://greynir.is) query engine. This is the repository for
the cross-platform Embla mobile client.

The client is implemented in [Dart](https://dart.dev/) using the
[Flutter](https://flutter.dev) framework. Currently built to run on
Android 8.1+ (SDK >= 27), with iOS support on the roadmap.

<a href="https://play.google.com/store/apps/details?id=is.mideind.embla">
    <img alt="Download on Google Play" src="img/play_store.png" width="180">
</a>

## Build instructions

Building the Embla client requires the Flutter framework:

* [Install Flutter](https://flutter.dev/docs/get-started/install)

Building for Android requires a recent version of Android Studio. Building for iOS
requires a recent version of Xcode.

Clone the repository:

```
git clone https://github.com/mideind/Embla_Flutter
```

In order to work as intended, the app requires a Service Account JSON configuration
file containing a key for Google's Speech-to-Text API. Get this document from
Google's API console and and save it at the following path within the repository:

```keys/gaccount.json```

Then run the following script:

```
/bin/bash keys/gen_keysfile.sh
```

You should now be able to build and run the app:

```
flutter run
```

This should launch the app in development mode on your device of choice (e.g.
simulator, attached physical device, etc.).

To build an Android `apk` debug binary for arm64, run the following script:

```
bash build.sh
```

## Screenshots

TBD

## Acknowledgements

The Embla client uses [Snowboy](https://github.com/seasalt-ai/snowboy) for hotword
detection and Google's [Speech-to-Text API](https://cloud.google.com/speech-to-text) for
speech recognition. Speech synthesis is accomplished via synthetic voices commissioned by
[Blindrafélagið](https://blind.is), the Icelandic Association of the Visually Impaired.

## License

Embla is Copyright (C) 2019-2022 [Miðeind ehf.](https://mideind.is)

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

The Embla logo, icon and other images are Copyright (C) Miðeind ehf. and may not
be used without permission.
