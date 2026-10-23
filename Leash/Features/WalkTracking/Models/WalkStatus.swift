import Foundation

enum GPSStatus: Equatable {
    case ready, waitingForPermission, waitingForFix, tracking, weakSignal, ignoringJump, denied, failed

    func message(in language: AppLanguage) -> String {
        switch self {
        case .ready: language.text("Ready", "準備好了")
        case .waitingForPermission: language.text("Waiting for location permission", "等待位置權限")
        case .waitingForFix: language.text("Waiting for GPS", "正在取得 GPS 位置")
        case .tracking: language.text("Tracking", "正在記錄散步")
        case .weakSignal: language.text("Weak GPS signal", "GPS 訊號較弱")
        case .ignoringJump: language.text("Ignoring GPS jump", "正在略過不準確的位置")
        case .denied: language.text("Location unavailable. Enable location in Settings to record your route.",
                                    "無法取得位置。請在 iOS 設定開啟位置權限，以記錄散步路線。")
        case .failed: language.text("Location temporarily unavailable. Please try again later.", "暫時無法取得位置，請稍後再試。")
        }
    }
}

enum WalkError: Error, Equatable {
    case storageUnavailable, load, save

    func message(in language: AppLanguage) -> String {
        switch self {
        case .storageUnavailable: language.text("Unable to open walk storage. Please try again.", "無法開啟散步紀錄，請再試一次。")
        case .load: language.text("Could not load walks. Your existing records have been preserved. Please try again.",
                                  "無法載入散步紀錄。原有資料已保留，請再試一次。")
        case .save: language.text("Could not save this change. Please try again.", "無法儲存這次變更，請再試一次。")
        }
    }
}
