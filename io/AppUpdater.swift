import Foundation
import Observation
import Sparkle

/// Sparkle with no window of its own: a newer version shows the panel's "Update Available…" row, and a click on the row installs it and relaunches the app.
@Observable
final class AppUpdater: NSObject, SPUUserDriver {
    private(set) var isUpdateAvailable = false
    @ObservationIgnored private var replyToUpdateFound: ((SPUUserUpdateChoice) -> Void)?
    @ObservationIgnored private var updater: SPUUpdater?

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

    func installUpdate() {
        isUpdateAvailable = false
        replyToUpdateFound?(.install)
        replyToUpdateFound = nil
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    /// Sparkle starts no other check while this reply waits, so the row stays until the click.
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        replyToUpdateFound = reply
        isUpdateAvailable = true
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
        isUpdateAvailable = false
        replyToUpdateFound = nil
    }
}
