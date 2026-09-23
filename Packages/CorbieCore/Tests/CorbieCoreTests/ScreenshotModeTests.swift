#if DEBUG
import CloudKit
import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct ScreenshotModeTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    private var today: Date { DomainClock.date("2026-09-23 10:30", in: calendar) }

    @Test func namesCarryTheScreenshotModeMarker() {
        #expect(ScreenshotModeStore.directoryName == "ScreenshotMode")
        #expect(ScreenshotModeFlag.sessionKey.hasPrefix("screenshotMode."))
        #expect(ScreenshotModeFlag.launchArgument == "-corbie-screenshot-mode")
        #expect(ScreenshotModeStore.defaultsSuiteName.contains("screenshot-mode"))
        #expect(ScreenshotModeStore.defaultsSuiteName != CorbieIdentifiers.appGroup)
        #expect(ScreenshotModeDemoImages.directoryName == "DemoAssets")
    }

    @Test func theLaunchArgumentTurnsTheModeOnOrOff() {
        let flag = ScreenshotModeFlag.launchArgument
        #expect(ScreenshotModeFlag.launchRequest(in: ["Corbie", flag, "on"]) == .on)
        #expect(ScreenshotModeFlag.launchRequest(in: ["Corbie", flag, "OFF"]) == .off)
        #expect(ScreenshotModeFlag.launchRequest(in: ["Corbie", flag]) == nil)
        #expect(ScreenshotModeFlag.launchRequest(in: ["Corbie", flag, "maybe"]) == nil)
        #expect(ScreenshotModeFlag.launchRequest(in: ["Corbie", "-corbie-reset-store"]) == nil)
    }

    @Test func seedingBuildsTheSpaceAndThePair() async throws {
        let seeded = try await seed()
        let space = seeded.result.space
        #expect(space.displayCurrency == "USD")
        #expect(space.togetherSince == DomainClock.date("2023-04-20 12:00", in: calendar))
        #expect(space.anchorTimeZone == TimeZone.current.identifier)
        #expect(space.memberCount == 2)
        #expect(space.creatorMemberId == seeded.result.me.id)
        #expect(space.subscriptionStatus == .active)

        let me = seeded.result.me
        #expect(me.displayName == "Alex")
        #expect(me.colorSlot == .teal)
        #expect(me.appleUserHash == AppleUserHash.value(ScreenshotModeDemo.meAppleUserId))
        let partner = seeded.result.partner
        #expect(partner.displayName == "Nora")
        #expect(partner.colorSlot == .rose)
        #expect(partner.birthdayMonth == 10)
        #expect(partner.birthdayDay == 5)

        let repositories = seeded.controller.repositories
        #expect(try await repositories.members.members(spaceId: space.id).map(\.id) == [me.id, partner.id])
        #expect(try await repositories.members.partner(of: me.id, spaceId: space.id)?.id == partner.id)
        let identity = MemberIdentity(store: ScreenshotModeSecretStore.signedInAsAlex())
        #expect(try await identity.currentMember(in: seeded.controller.stack)?.id == me.id)
        #expect(try await repositories.spaces.currentSpace(memberId: me.id)?.id == space.id)
    }

    @Test func seedingAddsTheTasksWithTodayAndTomorrowUpFront() async throws {
        let seeded = try await seed()
        let me = seeded.result.me.id
        let partner = seeded.result.partner.id
        let tasks = try await seeded.controller.repositories.tasks.tasks(TaskQuery(spaceId: seeded.result.space.id))
        let byTitle = Dictionary(uniqueKeysWithValues: tasks.map { ($0.title, $0) })
        #expect(tasks.count == 6)
        #expect(byTitle["Book the vet"]?.assigneeMemberId == me)
        #expect(byTitle["Book the vet"]?.takenAt == today)
        #expect(byTitle["Pick up the parcel"]?.assigneeMemberId == partner)
        let free = ["Change the light bulbs", "Call about the boiler", "Renew the car insurance", "Return the library books"]
        #expect(free.allSatisfy { byTitle[$0]?.isFree == true })
        #expect(tasks.allSatisfy { $0.isDone == false })

        let due = byTitle.mapValues { task in task.dueAt.map { DomainClock.text($0, in: calendar) } }
        #expect(due["Book the vet"] == "2026-09-23 00:00")
        #expect(due["Pick up the parcel"] == "2026-09-24 00:00")
        #expect(due["Change the light bulbs"] == "2026-09-23 00:00")
        #expect(due["Call about the boiler"] == "2026-09-24 00:00")
        #expect(due["Renew the car insurance"] == "2026-09-26 00:00")
        #expect(due["Return the library books"] == "2026-09-27 00:00")
    }

    @Test func seedingAddsNorasWishesWithoutImagesByDefault() async throws {
        let seeded = try await seed()
        let wishes = seeded.result.wishes
        #expect(wishes.map(\.title) == ["Wool coat", "Ceramics class", "Noise-cancelling headphones", "Linen bedding set"])
        #expect(wishes.map(\.price) == [240, 85, 299, 180])
        #expect(wishes.map(\.priority) == [.must, .want, .want, .want])
        #expect(wishes.allSatisfy { $0.currency == "USD" })
        #expect(wishes.allSatisfy { $0.ownerMemberId == seeded.result.partner.id })
        #expect(wishes.allSatisfy { $0.addedByMemberId == seeded.result.partner.id })
        #expect(wishes.allSatisfy { $0.localImage == nil && $0.imageURL == nil })
        let stored = try await seeded.controller.repositories.wishes.wishes(WishQuery(spaceId: seeded.result.space.id))
        #expect(stored.count == 4)
        #expect(stored.first?.title == "Wool coat")
    }

    @Test func imagesInTheDemoFolderBecomeDownsampledWishPhotos() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = NetTestSupport.pngImage(width: 2400, height: 1600)
        try photo.write(to: directory.appendingPathComponent("wool-coat.png"))
        try Data("not an image".utf8).write(to: directory.appendingPathComponent("ceramics-class.jpg"))

        let seeded = try await seed(images: ScreenshotModeDemoImages(directory: directory))
        let coat = try #require(seeded.result.wishes.first { $0.title == "Wool coat" })
        let image = try #require(coat.localImage)
        #expect(image.count <= ImageDownsampler.byteLimit)
        #expect(image.starts(with: [0xFF, 0xD8]))
        #expect(seeded.result.wishes.filter { $0.localImage != nil }.count == 1)
    }

    @Test func seedingAddsThePlansWithTheirTotals() async throws {
        let seeded = try await seed()
        let plans = try await seeded.controller.repositories.plans.plans(spaceId: seeded.result.space.id)
        let byTitle = Dictionary(uniqueKeysWithValues: plans.map { ($0.title, $0) })
        #expect(plans.count == 3)
        #expect(plans.allSatisfy { $0.currency == "USD" })

        let japan = try #require(byTitle["Japan, October"])
        #expect(japan.isOpenEnded == false)
        #expect(japan.targetAmount == 5000)
        #expect(japan.totalSavedAmount == 2400)

        let sofa = try #require(byTitle["New sofa"])
        #expect(sofa.isOpenEnded == false)
        #expect(sofa.targetAmount == 900)
        #expect(sofa.totalSavedAmount == 680)

        let rainy = try #require(byTitle["Rainy day"])
        #expect(rainy.isOpenEnded)
        #expect(rainy.totalSavedAmount == 1240)
        #expect(rainy.expenseCount == 4)
        let contributions = try await seeded.controller.repositories.plans.expenses(planId: rainy.id)
        let days = Set(contributions.map { calendar.startOfDay(for: $0.date ?? today) })
        #expect(days.count == 4)
        #expect(contributions.allSatisfy { ($0.date ?? today) < today })
        let earliest = try #require(contributions.compactMap(\.date).min())
        #expect(earliest >= DomainClock.date("2026-08-23", in: calendar))
    }

    @Test func seedingRevealsTheChoreSplitWithoutApplyingIt() async throws {
        let seeded = try await seed()
        let set = seeded.result.choreSet
        #expect(set.status == .revealed)
        #expect(set.appliedAt == nil)
        #expect(set.includedItems.count == ChoreSetDTO.minimumIncludedItems)
        let me = seeded.result.me.id
        let partner = seeded.result.partner.id
        let outcome = Dictionary(uniqueKeysWithValues: set.items.compactMap { item in
            item.catalogId.map { ($0, item.assignment) }
        })
        #expect(outcome[ScreenshotModeDemo.dishes]??.result == .member)
        #expect(outcome[ScreenshotModeDemo.dishes]??.assignedMemberId == partner)
        #expect(outcome[ScreenshotModeDemo.trash]??.result == .member)
        #expect(outcome[ScreenshotModeDemo.trash]??.assignedMemberId == me)
        for rotating in [ScreenshotModeDemo.bathroom, ScreenshotModeDemo.ironing, ScreenshotModeDemo.fridge] {
            #expect(outcome[rotating]??.result == .rotate)
        }
        let applied = try await seeded.controller.repositories.tasks.tasks(TaskQuery(spaceId: seeded.result.space.id))
        #expect(applied.contains { $0.choreItemId != nil } == false)
    }

    @Test func theEngineSplitsTheSeededVerdictsTheSameWayForAnyIds() throws {
        let catalog = ChoreCatalog.bundled
        for _ in 0 ..< 200 {
            let alex = UUID()
            let nora = UUID()
            let ids = Dictionary(uniqueKeysWithValues: ScreenshotModeDemo.chores.map { ($0.catalogId, UUID()) })
            let alexIsA = alex.uuidString < nora.uuidString
            let candidates = try ScreenshotModeDemo.chores.map { chore in
                let entry = try #require(catalog.item(id: chore.catalogId))
                return ChoreSplitCandidate(
                    id: try #require(ids[chore.catalogId]),
                    loadPerWeek: entry.loadPerWeek,
                    verdictA: alexIsA ? chore.alex : chore.nora,
                    verdictB: alexIsA ? chore.nora : chore.alex
                )
            }
            let outcome = ChoreSplitEngine.split(
                candidates,
                memberAId: alexIsA ? alex : nora,
                memberBId: alexIsA ? nora : alex
            )
            func decision(_ catalogId: String) -> ChoreSplitDecision? {
                ids[catalogId].flatMap { outcome.decision(for: $0) }
            }
            #expect(decision(ScreenshotModeDemo.dishes)?.assignedMemberId == nora)
            #expect(decision(ScreenshotModeDemo.trash)?.assignedMemberId == alex)
            #expect(decision(ScreenshotModeDemo.bathroom)?.result == .rotate)
            #expect(decision(ScreenshotModeDemo.ironing)?.result == .rotate)
            #expect(decision(ScreenshotModeDemo.fridge)?.result == .rotate)
        }
    }

    @Test func theSeededRatingsRunThroughTheEngineToTheSameReveal() async throws {
        let seeded = try await seed()
        let me = seeded.result.me.id
        let partner = seeded.result.partner.id
        let ids = [me, partner].sorted { $0.uuidString < $1.uuidString }
        let items = seeded.result.choreSet.includedItems
        let candidates = try items.map { item in
            ChoreSplitCandidate(
                id: item.id,
                loadPerWeek: item.frequency.loadPerWeek,
                verdictA: try #require(item.verdict(of: ids[0])),
                verdictB: try #require(item.verdict(of: ids[1]))
            )
        }
        let outcome = ChoreSplitEngine.split(candidates, memberAId: ids[0], memberBId: ids[1])
        func decision(_ catalogId: String) throws -> ChoreSplitDecision {
            let item = try #require(items.first { $0.catalogId == catalogId })
            return try #require(outcome.decision(for: item.id))
        }
        #expect(try decision(ScreenshotModeDemo.dishes).assignedMemberId == partner)
        #expect(try decision(ScreenshotModeDemo.trash).assignedMemberId == me)
        #expect(try decision(ScreenshotModeDemo.bathroom).result == .rotate)
        #expect(try decision(ScreenshotModeDemo.ironing).result == .rotate)
        #expect(try decision(ScreenshotModeDemo.fridge).result == .rotate)
    }

    @Test func seedingSealsTheTwoCapsules() async throws {
        let seeded = try await seed()
        let capsules = seeded.result.capsules
        let me = seeded.result.me.id
        let partner = seeded.result.partner.id
        #expect(capsules.count == 2)
        #expect(capsules.allSatisfy { $0.isUnlocked(at: today) == false && $0.openedAt == nil })
        let fromNora = try #require(capsules.first { $0.authorMemberId == partner })
        #expect(fromNora.recipientMemberId == me)
        #expect(fromNora.opensAt.map { DomainClock.text($0, in: calendar) } == "2027-02-14 09:00")
        let fromAlex = try #require(capsules.first { $0.authorMemberId == me })
        #expect(fromAlex.recipientMemberId == partner)
        #expect(fromAlex.opensAt.map { DomainClock.text($0, in: calendar) } == "2027-04-20 09:00")
    }

    @Test func seedingAnswersTodaysQuestionForBothAndMarksTheRevealRead() async throws {
        let seeded = try await seed()
        let question = seeded.result.question
        let me = seeded.result.me
        let dayKey = QuestionSelector.dayKey(for: today, timeZone: seeded.result.space.anchorCalendarTimeZone)
        #expect(question.questionId == ScreenshotModeDemo.questionId)
        #expect(question.dayKey == dayKey)
        #expect(question.isRevealed)
        #expect(Set(question.answers.compactMap(\.memberId)) == [me.id, seeded.result.partner.id])
        #expect(me.revealReadDays.dayKeys.contains(dayKey))
        #expect(me.lastQuestionSeenDayKey == dayKey)
        let stored = try await seeded.controller.repositories.questions.storedQuestion(
            spaceId: seeded.result.space.id,
            viewerMemberId: me.id,
            now: today
        )
        #expect(stored?.id == question.id)
        #expect(stored?.answers.count == 2)
    }

    @Test func theDemoStackHasNoCloudKitAndLivesOutsideTheRealStores() throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let controller = sandbox.store.open(session: "one", author: .app)
        let stack = controller.stack
        #expect(controller.screenshotModeSession == "one")
        #expect(stack.loadFailure == nil)
        #expect(stack.mirroring == .disabled)
        #expect(stack.cloudKitContainer == nil)
        #expect((stack.container is NSPersistentCloudKitContainer) == false)
        #expect(stack.container.persistentStoreDescriptions.count == 2)
        #expect(stack.container.persistentStoreDescriptions.allSatisfy { $0.cloudKitContainerOptions == nil })
        let directory = sandbox.store.directory(for: "one").standardizedFileURL.path
        let storeURLs = stack.container.persistentStoreCoordinator.persistentStores.compactMap(\.url)
        #expect(storeURLs.count == 2)
        #expect(storeURLs.allSatisfy { $0.deletingLastPathComponent().standardizedFileURL.path == directory })
        #expect(directory != sandbox.realDirectory.standardizedFileURL.path)

        let defaultRoot = ScreenshotModeStore.defaultRoot().standardizedFileURL
        let realStores = CoreDataStack.storesDirectory().standardizedFileURL
        #expect(defaultRoot != realStores)
        #expect(defaultRoot.deletingLastPathComponent().path == realStores.path)
        #expect(defaultRoot.lastPathComponent == ScreenshotModeStore.directoryName)

        let excluded = try sandbox.store.root.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(excluded.isExcludedFromBackup == true)
    }

    @Test func theDemoHistoryTokensStayOutOfTheAppGroupDefaults() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let tokenKey = StoreReset.historyTokenKey(author: .app)
        let before = UserDefaults.corbieShared.data(forKey: tokenKey)
        let app = sandbox.store.open(session: "one", author: .app)
        let widgets = sandbox.store.open(session: "one", author: .widgets)
        _ = try await widgets.repositories.spaces.create(displayCurrency: "USD")
        _ = try app.stack.processHistory()
        #expect(sandbox.store.defaults.data(forKey: tokenKey) != nil)
        #expect(UserDefaults.corbieShared.data(forKey: tokenKey) == before)
    }

    @MainActor
    @Test func sharingOnTheDemoStackRefusesToShareOrInvite() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let controller = sandbox.store.open(session: "one", author: .app)
        let result = try await ScreenshotModeSeeder(today: today, calendar: calendar).seed(into: controller)
        let sharing = CloudKitSharing(stack: controller.stack)
        let notConfigured = CorbieError.cloudKit("CloudKit container is not configured")
        await #expect(throws: notConfigured) {
            _ = try await sharing.share(space: result.space.id)
        }
        #expect(throws: notConfigured) {
            _ = try sharing.existingShare(for: result.space.id)
        }
        await #expect(throws: notConfigured) {
            _ = try await sharing.removeDepartedMembers(space: result.space.id, ownerMemberId: result.me.id)
        }
    }

    @Test func enteringAndLeavingNeverWritesToTheRealStore() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let real = sandbox.realController()
        let realSpace = try await real.repositories.spaces.create(displayCurrency: "EUR")
        let realMe = try await real.repositories.members.upsertCurrentMember(
            appleUserId: "real.me",
            spaceId: realSpace.id,
            draft: MemberDraft(displayName: "Real me", colorKey: MemberColorSlot.blue.rawValue),
            theme: .sand
        ).member
        _ = try await real.repositories.tasks.create(TaskDraft(spaceId: realSpace.id, title: "Real task"))
        let realIdentity = MemberIdentity(store: InMemorySecretStore())
        try realIdentity.setAppleUserID("real.me")
        let reloads = ReloadCounter()
        let intents = sandbox.intents()
        intents.use(controller: real, identity: realIdentity)
        let widgetProcess = sandbox.intents()
        widgetProcess.use(controller: real, identity: realIdentity)
        let lifecycle = sandbox.lifecycle(intents: intents, now: today, calendar: calendar, reloads: reloads)
        _ = try real.stack.processHistory()
        let before = try StoreSnapshot(real)
        let appGroupBefore = sandbox.appGroupDomain

        let first = try await lifecycle.enter()
        #expect(sandbox.flag.session == first.id)
        var appGroupInTheMode = sandbox.appGroupDomain
        let flagged = appGroupInTheMode.removeValue(forKey: ScreenshotModeFlag.sessionKey) as? String
        #expect(flagged == first.id)
        #expect(appGroupInTheMode as NSDictionary == appGroupBefore as NSDictionary)
        #expect(intents.controller() === first.controller)
        #expect(try await intents.currentMemberId() != realMe.id)
        let demoSpace = try #require(try await first.controller.repositories.spaces.currentSpace(memberId: nil))
        let demoTask = try #require(
            try await first.controller.repositories.tasks.tasks(TaskQuery(spaceId: demoSpace.id))
                .first { $0.isFree }
        )
        _ = try await TaskIntentRunner.take(taskId: demoTask.id, persistence: intents, now: today)

        let widgetReloads = NotificationCenter.default.addObserver(
            forName: WidgetReloadRequest.notificationName,
            object: nil,
            queue: nil
        ) { _ in
            _ = widgetProcess.controller()
        }
        let second = try await lifecycle.enter()
        NotificationCenter.default.removeObserver(widgetReloads)
        #expect(second.id != first.id)
        #expect(FileManager.default.fileExists(atPath: sandbox.store.directory(for: first.id).path) == false)
        #expect(widgetProcess.controller().screenshotModeSession == second.id)
        let secondSpace = try #require(try await second.controller.repositories.spaces.currentSpace(memberId: nil))
        let freshTasks = try await second.controller.repositories.tasks.tasks(TaskQuery(spaceId: secondSpace.id))
        #expect(freshTasks.count == ScreenshotModeDemo.tasks.count)
        #expect(freshTasks.filter { $0.isFree }.count == 4)

        lifecycle.leave(returningTo: real, identity: realIdentity)
        #expect(sandbox.flag.isOn == false)
        #expect(intents.controller() === real)
        #expect(try await intents.currentMemberId() == realMe.id)
        #expect(reloads.count == 3)

        #expect(try StoreSnapshot(real) == before)
        #expect(sandbox.appGroupDomain as NSDictionary == appGroupBefore as NSDictionary)
        let realTasks = try await real.repositories.tasks.tasks(TaskQuery(spaceId: realSpace.id))
        #expect(realTasks.map(\.title) == ["Real task"])
        #expect(try await real.repositories.members.members(spaceId: realSpace.id).map(\.displayName) == ["Real me"])
        #expect(try await real.repositories.members.member(appleUserId: ScreenshotModeDemo.meAppleUserId) == nil)
        #expect(try await real.repositories.spaces.currentSpace(memberId: realMe.id)?.id == realSpace.id)
    }

    @Test func resumeReopensASeededSessionAndRefusesAnythingElse() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let lifecycle = sandbox.lifecycle(intents: sandbox.intents(), now: today, calendar: calendar)
        #expect(await lifecycle.resume() == nil)

        let entered = try await lifecycle.enter()
        let resumed = try #require(await sandbox.lifecycle(intents: sandbox.intents(), now: today, calendar: calendar).resume())
        #expect(resumed.id == entered.id)
        #expect(try await resumed.identity.currentMember(in: resumed.controller.stack)?.displayName == "Alex")

        sandbox.flag.turnOn(session: "missing")
        #expect(await lifecycle.resume() == nil)
        _ = sandbox.store.open(session: "empty", author: .app)
        sandbox.flag.turnOn(session: "empty")
        #expect(await lifecycle.resume() == nil)
    }

    @Test func aRelaunchOnALaterDayReseedsInsteadOfResuming() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let entered = try await sandbox.lifecycle(intents: sandbox.intents(), now: today, calendar: calendar).enter()
        let lateTonight = DomainClock.date("2026-09-23 23:59", in: calendar)
        let tonight = sandbox.lifecycle(intents: sandbox.intents(), now: lateTonight, calendar: calendar)
        #expect(await tonight.resume()?.id == entered.id)

        let tomorrow = DomainClock.date("2026-09-24 00:01", in: calendar)
        let nextDay = sandbox.lifecycle(intents: sandbox.intents(), now: tomorrow, calendar: calendar)
        #expect(await nextDay.resume() == nil)
        let reseeded = try await nextDay.enter()
        #expect(reseeded.id != entered.id)
        let space = try #require(try await reseeded.controller.repositories.spaces.currentSpace(memberId: nil))
        let tasks = try await reseeded.controller.repositories.tasks.tasks(TaskQuery(spaceId: space.id))
        let vet = try #require(tasks.first { $0.title == "Book the vet" })
        #expect(vet.dueAt.map { DomainClock.text($0, in: calendar) } == "2026-09-24 00:00")
        #expect(await nextDay.resume()?.id == reseeded.id)
    }

    @Test func intentPersistenceFollowsTheFlagBothWays() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        let real = PersistenceController.inMemory()
        let realIdentity = MemberIdentity(store: InMemorySecretStore())
        try realIdentity.setAppleUserID("real.me")
        let appProcess = sandbox.intents()
        appProcess.use(controller: real, identity: realIdentity)
        let widgetProcess = sandbox.intents()
        widgetProcess.use(controller: real, identity: realIdentity)
        #expect(appProcess.controller() === real)
        #expect(appProcess.identity().currentAppleUserID == "real.me")

        let notificationActions = IntentPersistence.pinned(to: real, identity: realIdentity)

        let lifecycle = sandbox.lifecycle(intents: appProcess, now: today, calendar: calendar)
        let first = try await lifecycle.enter()
        #expect(notificationActions.controller() === real)
        #expect(notificationActions.identity().currentAppleUserID == "real.me")
        #expect(appProcess.controller() === first.controller)
        #expect(appProcess.identity().currentAppleUserID == ScreenshotModeDemo.meAppleUserId)
        let opened = widgetProcess.controller()
        #expect(opened !== real)
        #expect(opened.screenshotModeSession == first.id)
        #expect(widgetProcess.controller() === opened)
        #expect(widgetProcess.identity().currentAppleUserID == ScreenshotModeDemo.meAppleUserId)
        let alex = try await first.identity.currentMember(in: first.controller.stack)
        #expect(try await widgetProcess.currentMemberId() == alex?.id)
        #expect(opened.stack.author == .widgets)
        #expect(opened.stack.cloudKitContainer == nil)

        let second = try await lifecycle.enter()
        let reopened = widgetProcess.controller()
        #expect(reopened !== opened)
        #expect(reopened.screenshotModeSession == second.id)

        lifecycle.leave(returningTo: real, identity: realIdentity)
        #expect(appProcess.controller() === real)
        #expect(widgetProcess.controller() === real)
        #expect(widgetProcess.identity().currentAppleUserID == "real.me")

        appProcess.use(controller: second.controller, identity: second.identity)
        #expect(appProcess.controller() === real)
        #expect(appProcess.identity().currentAppleUserID == "real.me")
        sandbox.flag.turnOn(session: second.id)
        #expect(appProcess.controller().screenshotModeSession == second.id)
        #expect(appProcess.identity().currentAppleUserID == ScreenshotModeDemo.meAppleUserId)
    }

    @Test func wipeRemovesTheDemoFilesAndTheDemoDefaults() throws {
        let sandbox = try Sandbox()
        defer { sandbox.clean() }
        _ = sandbox.store.open(session: "one", author: .app)
        sandbox.store.defaults.set(true, forKey: "corbie.chore.nudged")
        #expect(sandbox.store.hasStore(for: "one"))
        sandbox.store.wipe()
        #expect(FileManager.default.fileExists(atPath: sandbox.store.root.path) == false)
        #expect(sandbox.store.hasStore(for: "one") == false)
        #expect(sandbox.store.defaults.object(forKey: "corbie.chore.nudged") == nil)
        #expect(FileManager.default.fileExists(atPath: sandbox.realDirectory.path))
    }

    private struct Seeded {
        let controller: PersistenceController
        let result: ScreenshotModeSeedResult
    }

    private func seed(images: ScreenshotModeDemoImages = .none) async throws -> Seeded {
        let controller = PersistenceController.inMemory(author: .app)
        let result = try await ScreenshotModeSeeder(today: today, calendar: calendar, images: images)
            .seed(into: controller)
        return Seeded(controller: controller, result: result)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-screenshot-mode-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct Sandbox {
    let realDirectory: URL
    let appGroupSuite = "corbie-screenshot-app-group-" + UUID().uuidString
    let demoSuite = "corbie-screenshot-demo-" + UUID().uuidString

    init() throws {
        realDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-app-group-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
    }

    var flag: ScreenshotModeFlag {
        ScreenshotModeFlag(defaults: appGroupDefaults)
    }

    var store: ScreenshotModeStore {
        ScreenshotModeStore(
            root: realDirectory.appendingPathComponent(ScreenshotModeStore.directoryName, isDirectory: true),
            defaultsSuiteName: demoSuite
        )
    }

    var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? UserDefaults()
    }

    var appGroupDomain: [String: Any] {
        appGroupDefaults.persistentDomain(forName: appGroupSuite) ?? [:]
    }

    func realController() -> PersistenceController {
        PersistenceController(stack: CoreDataStack(storesIn: realDirectory, author: .app, historyDefaults: appGroupDefaults))
    }

    func intents() -> IntentPersistence {
        IntentPersistence(screenshotModeFlag: flag, screenshotModeStore: store)
    }

    func lifecycle(
        intents: IntentPersistence,
        now: Date,
        calendar: Calendar,
        reloads: ReloadCounter = ReloadCounter()
    ) -> ScreenshotModeLifecycle {
        ScreenshotModeLifecycle(
            flag: flag,
            store: store,
            intents: intents,
            calendar: calendar,
            now: { now },
            reloadWidgets: { reloads.increment() }
        )
    }

    func clean() {
        try? FileManager.default.removeItem(at: realDirectory)
        for suite in [appGroupSuite, demoSuite] {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
    }
}

private struct StoreSnapshot: Equatable {
    let counts: [String: Int]
    let transactions: Int
    let lastTransaction: Date?

    init(_ controller: PersistenceController) throws {
        let context = controller.stack.newBackgroundContext()
        let read = try context.performAndWait {
            var counts: [String: Int] = [:]
            for name in CorbieModel.shared.entities.compactMap(\.name) {
                counts[name] = try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: name))
            }
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: Date.distantPast)
            let result = try context.execute(request) as? NSPersistentHistoryResult
            let history = result?.result as? [NSPersistentHistoryTransaction] ?? []
            return (counts, history.count, history.last?.timestamp)
        }
        counts = read.0
        transactions = read.1
        lastTransaction = read.2
    }
}
#endif
