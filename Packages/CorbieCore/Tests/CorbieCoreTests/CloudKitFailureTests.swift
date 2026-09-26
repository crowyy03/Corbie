import CloudKit
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CloudKitFailureTests {
    @Test func theLogKeepsTheCodeAndTheUnderlyingError() {
        let underlying = NSError(domain: "CKInternalErrorDomain", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Share not found"])
        let error = CKError(.unknownItem, userInfo: [NSUnderlyingErrorKey: underlying])
        let failure = CloudKitFailure(step: "fetch share metadata", error: error)

        #expect(failure.reason == .missing)
        #expect(failure.errorCode == CKError.Code.unknownItem.rawValue)
        #expect(failure.detail.hasPrefix("CKError 11 "))
        #expect(failure.detail.contains("underlying CKInternalErrorDomain 2003 Share not found"))
        #expect(failure.failureReason?.hasPrefix("fetch share metadata: missing: CKError 11") == true)
    }

    @Test func aPartialFailureNamesEachItemAndCarriesTheItemCode() throws {
        let link = try #require(URL(string: "https://www.icloud.com/share/0abcDEF#Corbie"))
        let error = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [link: CKError(.participantMayNeedVerification)]])
        let failure = CloudKitFailure(step: "fetch share metadata", error: error)

        #expect(failure.errorCode == CKError.Code.participantMayNeedVerification.rawValue)
        #expect(failure.reason == .other)
        #expect(failure.detail.contains("item \(ShareLinkLog.text(for: link)): CKError 33"))
    }

    @Test func onlyAGoneRecordOrZoneCountsAsMissing() {
        let missing: [CKError.Code] = [.unknownItem, .zoneNotFound, .userDeletedZone]
        for code in missing {
            #expect(CloudKitFailure.reason(for: CKError(code)) == .missing, "\(code)")
        }
        let notMissing: [CKError.Code] = [.assetFileNotFound, .permissionFailure, .badContainer, .internalError, .serverRejectedRequest]
        for code in notMissing {
            #expect(CloudKitFailure.reason(for: CKError(code)) != .missing, "\(code)")
        }
    }

    @Test func aNonCloudKitErrorKeepsItsDomainAndCode() {
        let failure = CloudKitFailure(step: "share create", error: NSError(domain: NSCocoaErrorDomain, code: 134_060))
        #expect(failure.errorCode == nil)
        #expect(failure.detail.hasPrefix("NSCocoaErrorDomain 134060 "))
    }

    @Test func theShareLinkFingerprintIsStableAndShort() throws {
        let link = try #require(URL(string: "https://www.icloud.com/share/0abcDEF#Corbie"))
        let other = try #require(URL(string: "https://www.icloud.com/share/0abcDEG#Corbie"))
        #expect(ShareLinkLog.fingerprint(of: link) == ShareLinkLog.fingerprint(of: link))
        #expect(ShareLinkLog.fingerprint(of: link) != ShareLinkLog.fingerprint(of: other))
        #expect(ShareLinkLog.fingerprint(of: link).count == 8)
    }

    @Test func theAccountFingerprintIsTheSHA256OfTheRecordName() {
        let fingerprint = CloudKitSharing.fingerprint(ofAccount: "_0123456789abcdef")
        #expect(fingerprint.count == 64)
        #expect(fingerprint.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) })
        #expect(fingerprint == CloudKitSharing.fingerprint(ofAccount: "_0123456789abcdef"))
        #expect(fingerprint != CloudKitSharing.fingerprint(ofAccount: "_0123456789abcdee"))
    }

    @Test func theDeclaredEnvironmentReadsTheEntitlementSpelling() {
        #expect(CloudKitEnvironment(declaration: "Development") == .development)
        #expect(CloudKitEnvironment(declaration: "Production") == .production)
        #expect(CloudKitEnvironment(declaration: "$(CORBIE_CLOUDKIT_ENVIRONMENT)") == nil)
        #expect(CloudKitEnvironment(declaration: nil) == nil)
    }
}
