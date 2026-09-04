// Spotify's two native pieces: the login sheet (ASWebAuthenticationSession,
// generic enough to be called `webAuth`) and starting playback in the Spotify
// app through its iOS SDK. Everything else about Spotify is Dart, in
// lib/spotify_client.dart.

import AuthenticationServices
import Flutter
import Foundation
import SpotifyiOS

enum EmblaSpotify {
    // Kept alive for the duration of the sheet / the hand-off to Spotify.
    private static var authSession: ASWebAuthenticationSession?
    private static let presenter = Presenter()
    private static var appRemote: SPTAppRemote?

    private final class Presenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
        }
    }

    /// Opens `url` in a system login sheet and returns the callback URL for
    /// `scheme` as a string.
    static func webAuth(url: URL, scheme: String, result: @escaping FlutterResult) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
            authSession = nil
            if let callback = callback {
                result(callback.absoluteString)
            } else {
                result(FlutterError(code: "auth_cancelled",
                                    message: "Innskráningu var hætt",
                                    details: error?.localizedDescription))
            }
        }
        session.presentationContextProvider = presenter
        authSession = session
        session.start()
    }

    /// Hands a Spotify URI to the Spotify app, which asks for authorization
    /// on first use and starts playing. Returns to Embla via the redirect URI.
    static func play(clientID: String, redirectURI: URL, uri: String, result: @escaping FlutterResult) {
        let config = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        let remote = SPTAppRemote(configuration: config, logLevel: .none)
        appRemote = remote
        // `success` only says whether the Spotify app is installed and took
        // the request; playback itself happens over there.
        remote.authorizeAndPlayURI(uri) { success in
            DispatchQueue.main.async {
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "not_installed",
                                        message: "Spotify appið er ekki uppsett",
                                        details: nil))
                }
            }
        }
    }
}
