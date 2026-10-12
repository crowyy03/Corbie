import CorbieCore
import XCTest
@testable import Corbie

final class CapsuleOpenLaunchTests: XCTestCase {
    @MainActor
    func testALetterStoredAfterTheBacklogRanIsScheduledByTheReplanAndOnTheNextSessionLoad() async throws {
        let center = RecordingNotificationClient()
        let environment = AppEnvironment(
            persistence: PersistenceController.inMemory(),
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: center,
            transport: OfflineLetterTransport()
        )
        let repositories = environment.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "000123.me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya"),
            theme: environment.theme.activeTheme
        ).member
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "000456.partner",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Sofia"),
            theme: environment.theme.activeTheme
        ).member
        try environment.storeAppleCredential(userIdentifier: "000123.me", identityToken: nil)
        await environment.reloadSession()
        let beforeAnyLetter = await center.requests
        XCTAssertTrue(beforeAnyLetter.isEmpty)

        let first = try await storeLetter(from: partner.id, to: me.id, inDays: 3, space: space.id, in: repositories)
        await environment.replanCapsuleOpens()
        let afterReplan = await center.requests
        XCTAssertEqual(afterReplan.map(\.id), [NotificationIdentifier.capsuleOpens(capsuleId: first.id)])
        let second = try await storeLetter(from: partner.id, to: me.id, inDays: 5, space: space.id, in: repositories)
        await environment.reloadSession()

        let requests = await center.requests
        XCTAssertEqual(
            Set(requests.map(\.id)),
            [NotificationIdentifier.capsuleOpens(capsuleId: first.id), NotificationIdentifier.capsuleOpens(capsuleId: second.id)]
        )
        XCTAssertEqual(requests.first { $0.id == NotificationIdentifier.capsuleOpens(capsuleId: second.id) }?.fireDate, second.opensAt)
        XCTAssertEqual(Set(requests.map(\.content.titleKey)), [NotificationStrings.capsuleReceivedTitle])
    }

    private func storeLetter(
        from author: UUID,
        to recipient: UUID,
        inDays days: Int,
        space: UUID,
        in repositories: Repositories
    ) async throws -> CapsuleDTO {
        let day = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: days, to: Date()))
        let opensAt = try XCTUnwrap(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day))
        return try await repositories.capsules.create(
            CapsuleDraft(
                spaceId: space,
                authorMemberId: author,
                recipientMemberId: recipient,
                title: "Letter in \(days) days",
                body: "Check the top drawer.",
                opensAt: opensAt
            )
        )
    }
}

private actor RecordingNotificationClient: NotificationCenterClient {
    private(set) var requests: [CorbieNotificationRequest] = []

    func authorizationStatus() async -> NotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func registerCategories(_ categories: [NotificationCategoryDescriptor]) async {}
    func pendingIdentifiers() async -> [String] { requests.map(\.id) }

    func add(_ request: CorbieNotificationRequest) async throws {
        requests.removeAll { $0.id == request.id }
        requests.append(request)
    }

    func removePending(identifiers: [String]) async {
        requests.removeAll { identifiers.contains($0.id) }
    }
}

private struct OfflineLetterTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}
