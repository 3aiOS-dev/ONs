import UIKit

/// Performs the only privacy-safe availability check iOS exposes for another app:
/// `canOpenURL` on a declared custom URL scheme. A missing or undeclared
/// scheme is treated as unverified, so iStore never shows a false second-copy
/// prompt after the app has been deleted.
@MainActor
enum InstalledAppDetector {
    private enum CheckResult {
        case installed
        case notInstalled
        case unavailable
    }

    /// Returns true only when iOS can verify a declared URL scheme.
    static func isInstalled(_ app: RepoApp) -> Bool {
        check(app) == .installed
    }

    /// A local delivery record is only a hint. It must never be enough to show
    /// the second-copy dialog: iOS must confirm that the target app is actually
    /// installed. If verification is unavailable, start a normal install and
    /// clear the stale local record instead of showing a false prompt.
    static func shouldOfferSecondCopy(for app: RepoApp, hasLocalInstallRecord: Bool) -> Bool {
        guard hasLocalInstallRecord else { return false }
        return check(app) == .installed
    }

    private static func check(_ app: RepoApp) -> CheckResult {
        let permittedSchemes = Set(
            ((Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]) ?? [])
                .map { $0.lowercased() }
        )

        var hasCheckableScheme = false
        for rawScheme in app.urlSchemes {
            let scheme = normalizedScheme(rawScheme)
            guard !scheme.isEmpty else { continue }
            guard permittedSchemes.contains(scheme),
                  let url = URL(string: "\(scheme)://") else {
                continue
            }
            hasCheckableScheme = true
            if UIApplication.shared.canOpenURL(url) {
                return .installed
            }
        }
        return hasCheckableScheme ? .notInstalled : .unavailable
    }

    private static func normalizedScheme(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
