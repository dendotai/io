import Foundation
import Observation
import Sparkle

/// Sparkle with no window of its own: a newer version shows `updateTitle` in the panel and the right-click menu, and a click there installs the version and relaunches the app.
@Observable
final class AppUpdater: NSObject, SPUUserDriver {
    private var pendingUpdate: (version: String, reply: (SPUUserUpdateChoice) -> Void)?
    /// Held only to keep Sparkle running.
    @ObservationIgnored private var updater: SPUUpdater?

    var availableVersion: String? { pendingUpdate?.version }
    var updateTitle: String? { availableVersion.map { "Update to \($0)" } }

    /// Only the release script sets `PUBLISHED_RELEASE`, so a local build never replaces itself with a published release.
    func start() {
        #if PUBLISHED_RELEASE
            let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
            do {
                try updater.start()
                self.updater = updater
            } catch {
                NSLog("io: updater start failed: \(error)")
            }
        #endif
    }

    #if DEBUG
        func showUpdateWithoutChecking(version: String) {
            pendingUpdate = (version, { _ in })
        }
    #endif

    func installUpdate() {
        pendingUpdate?.reply(.install)
        pendingUpdate = nil
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    /// Sparkle starts no other check while this reply waits, so the row stays until the click.
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // An information-only item has nothing to install, and Sparkle's documentation forbids an install reply to it.
        if appcastItem.isInformationOnlyUpdate {
            reply(.dismiss)
        } else {
            pendingUpdate = (appcastItem.displayVersionString, reply)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    /// The next daily check finds the update again and the row returns.
    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        NSLog("io: update failed: \(error)")
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {}

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}

    func showDownloadDidReceiveData(ofLength length: UInt64) {}

    func showDownloadDidStartExtractingUpdate() {}

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        reply(.install)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        pendingUpdate = nil
    }
}
