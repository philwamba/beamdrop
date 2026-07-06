import AppIntents
import BeamDropIOSCore
import UIKit

struct SendClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Clipboard with BeamDrop"
    static var description = IntentDescription("Manually sends current clipboard text to BeamDrop. BeamDrop does not monitor clipboard silently.")

    func perform() async throws -> some IntentResult {
        _ = UIPasteboard.general.string
        return .result()
    }
}
