import CloudKit
import Foundation

struct CloudKitErrorReport: Sendable, Equatable {
    struct RecordFailure: Sendable, Equatable {
        let recordName: String?
        let zoneName: String?
        let code: Int
    }

    let domain: String
    let code: Int
    let underlyingDomain: String?
    let underlyingCode: Int?
    let records: [RecordFailure]

    init(
        domain: String,
        code: Int,
        underlyingDomain: String? = nil,
        underlyingCode: Int? = nil,
        records: [RecordFailure] = []
    ) {
        self.domain = domain
        self.code = code
        self.underlyingDomain = underlyingDomain
        self.underlyingCode = underlyingCode
        self.records = records
    }

    init(_ error: any Error) {
        let top = error as NSError
        let underlying = top.userInfo[NSUnderlyingErrorKey] as? NSError
        let partialFailure = [top, underlying].compactMap { $0 }.first(where: CloudKitErrorReport.isPartialFailure)
        let partials = partialFailure?.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error] ?? [:]
        self.init(
            domain: top.domain,
            code: top.code,
            underlyingDomain: underlying?.domain,
            underlyingCode: underlying?.code,
            records: partials
                .map { RecordFailure(item: $0.key, error: $0.value) }
                .sorted { ($0.zoneName ?? "", $0.recordName ?? "") < ($1.zoneName ?? "", $1.recordName ?? "") }
        )
    }

    private static func isPartialFailure(_ error: NSError) -> Bool {
        error.domain == CKErrorDomain && error.code == CKError.Code.partialFailure.rawValue
    }
}

private extension CloudKitErrorReport.RecordFailure {
    init(item: AnyHashable, error: any Error) {
        let code = (error as NSError).code
        switch item.base {
        case let record as CKRecord.ID:
            self.init(recordName: record.recordName, zoneName: record.zoneID.zoneName, code: code)
        case let zone as CKRecordZone.ID:
            self.init(recordName: nil, zoneName: zone.zoneName, code: code)
        default:
            self.init(recordName: nil, zoneName: nil, code: code)
        }
    }
}
