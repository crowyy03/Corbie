import CorbieCore
import XCTest
@testable import Corbie

@MainActor
final class TasksFolderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    func testFolderChipsPutTheShoppingFolderFirst() async throws {
        let fixture = try await TasksFixture.make(now: now)
        _ = try await fixture.controller.repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: fixture.space.id, title: "Places to go", template: .places)
        )
        _ = try await fixture.controller.repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: fixture.space.id, title: "To watch", template: .watch)
        )
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        XCTAssertEqual(model.folders.map(\.title), ["Shopping", "Places to go", "To watch"])
        XCTAssertEqual(model.folderSelection, .all)
    }

    func testAFolderShowsTickedLinesLastAndCountsOnlyTheOpenOnes() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let tasks = fixture.controller.repositories.tasks
        let bread = try await tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "Bread",
                assigneeMemberId: fixture.me.id,
                folderId: fixture.shopping.id,
                createdByMemberId: fixture.me.id
            )
        )
        _ = try await tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "Batteries",
                folderId: fixture.shopping.id,
                createdByMemberId: fixture.partner.id
            )
        )
        _ = try await tasks.setDone(taskId: bread.id, isDone: true, memberId: fixture.me.id, at: now)

        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(fixture.shopping.id))

        XCTAssertEqual(model.items.map(\.title), ["Coffee", "Batteries", "Bread"])
        XCTAssertEqual(model.items.map(\.isDone), [false, false, true])
        XCTAssertEqual(model.counts.all, 2)
        XCTAssertEqual(model.counts.mine, 0)
        XCTAssertEqual(model.counts.free, 2)
        XCTAssertTrue(model.showsClearDone)
    }

    func testClearDoneKeepsTheOpenLines() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let tasks = fixture.controller.repositories.tasks
        let bread = try await tasks.create(
            TaskDraft(spaceId: fixture.space.id, title: "Bread", folderId: fixture.shopping.id)
        )
        _ = try await tasks.setDone(taskId: bread.id, isDone: true, memberId: fixture.me.id, at: now)

        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(fixture.shopping.id))
        XCTAssertTrue(model.showsClearDone)

        await model.clearDone()

        XCTAssertEqual(model.items.map(\.title), ["Coffee"])
        XCTAssertFalse(model.showsClearDone)
    }

    func testTickingInAFolderMarksAndReopensTheLine() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(fixture.shopping.id))
        let coffee = try XCTUnwrap(model.items.first)

        await model.toggleDone(coffee)
        XCTAssertEqual(model.items.first?.isDone, true)

        let ticked = try XCTUnwrap(model.items.first)
        await model.toggleDone(ticked)
        XCTAssertEqual(model.items.first?.isDone, false)
    }

    func testOnlyTheAuthorTicksWhenTheFolderSaysSo() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let tasks = fixture.controller.repositories.tasks
        let folder = try await tasks.createFolder(
            TaskFolderDraft(
                spaceId: fixture.space.id,
                title: "To watch",
                template: .watch,
                anyoneCanCheck: false,
                createdByMemberId: fixture.partner.id
            )
        )
        _ = try await tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "Their pick",
                folderId: folder.id,
                createdByMemberId: fixture.partner.id
            )
        )
        _ = try await tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "My pick",
                folderId: folder.id,
                createdByMemberId: fixture.me.id
            )
        )

        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(folder.id))

        let theirs = try XCTUnwrap(model.items.first { $0.title == "Their pick" })
        let mine = try XCTUnwrap(model.items.first { $0.title == "My pick" })
        XCTAssertFalse(model.canTick(theirs))
        XCTAssertTrue(model.canTick(mine))
    }

    func testDeletingAFolderKeepsItsTasksAsPlainOnes() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let folder = try await fixture.controller.repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: fixture.space.id, title: "Cities", template: .cities)
        )
        _ = try await fixture.controller.repositories.tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "Porto",
                folderId: folder.id,
                createdByMemberId: fixture.me.id
            )
        )
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(folder.id))

        await model.deleteSelectedFolder()

        XCTAssertEqual(model.folderSelection, .all)
        XCTAssertEqual(model.folders.map(\.title), ["Shopping"])
        XCTAssertTrue(model.items.contains { $0.title == "Porto" })
    }

    func testThePinnedShoppingFolderCannotBeDeleted() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(fixture.shopping.id))

        await model.deleteSelectedFolder()

        XCTAssertEqual(model.folders.map(\.title), ["Shopping"])
        XCTAssertEqual(model.folderSelection, .folder(fixture.shopping.id))
    }

    func testTheMapToggleNeedsAPlacedTask() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let folder = try await fixture.controller.repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: fixture.space.id, title: "Places to go", template: .places)
        )
        _ = try await fixture.controller.repositories.tasks.create(
            TaskDraft(spaceId: fixture.space.id, title: "Somewhere", folderId: folder.id)
        )
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        await model.select(.folder(folder.id))
        XCTAssertFalse(model.showsMapToggle)

        _ = try await fixture.controller.repositories.tasks.create(
            TaskDraft(
                spaceId: fixture.space.id,
                title: "Time Out Market",
                folderId: folder.id,
                placeName: "Time Out Market",
                address: "Av. 24 de Julho, Lisbon",
                lat: 38.7067,
                lon: -9.1459
            )
        )
        await model.load()

        XCTAssertTrue(model.showsMapToggle)
        XCTAssertEqual(model.placedTasks.map(\.title), ["Time Out Market"])
        model.toggleMode()
        XCTAssertEqual(model.mode, .map)
        XCTAssertEqual(fixture.analytics.names, ["folder_map_opened"])
    }

    func testMovingATaskIntoAFolderTakesItOutOfTheAllList() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let milk = try XCTUnwrap(model.items.first { $0.title == "Buy milk" })

        await model.move(milk, to: fixture.shopping.id)

        XCTAssertFalse(model.items.contains { $0.title == "Buy milk" })
        await model.select(.folder(fixture.shopping.id))
        XCTAssertTrue(model.items.contains { $0.title == "Buy milk" })
    }

    func testTheShoppingTemplateCreatesThePinnedFolderOnlyOnce() async throws {
        let controller = PersistenceController.inMemory()
        let repositories = controller.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: now)
        let context = TasksContext(spaceId: space.id, memberId: UUID())
        let analytics = TasksRecordingAnalytics()

        let first = FolderEditorViewModel(
            folder: nil,
            context: context,
            repository: repositories.tasks,
            analytics: analytics
        )
        first.title = "Shopping"
        first.template = .shopping
        let pinnedFolder = await first.save()
        let pinned = try XCTUnwrap(pinnedFolder)
        XCTAssertTrue(pinned.isPinnedShopping)

        let second = FolderEditorViewModel(
            folder: nil,
            context: context,
            repository: repositories.tasks,
            analytics: analytics
        )
        second.title = "Groceries"
        second.template = .shopping
        let plainFolder = await second.save()
        let plain = try XCTUnwrap(plainFolder)

        let titles = try await repositories.tasks.folders(spaceId: space.id).map(\.title)
        XCTAssertFalse(plain.isPinnedShopping)
        XCTAssertEqual(titles, ["Shopping", "Groceries"])
        XCTAssertEqual(analytics.names, ["folder_created", "folder_created"])
    }

    func testEditingAFolderKeepsItPinnedAndStoresTheTickRule() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let model = FolderEditorViewModel(
            folder: fixture.shopping,
            context: fixture.context,
            repository: fixture.controller.repositories.tasks,
            analytics: fixture.analytics
        )
        model.title = "Groceries"
        model.subtitle = "Lisbon, this fall"
        model.anyoneCanCheck = false

        let savedFolder = await model.save()
        let saved = try XCTUnwrap(savedFolder)

        XCTAssertEqual(saved.title, "Groceries")
        XCTAssertEqual(saved.subtitle, "Lisbon, this fall")
        XCTAssertFalse(saved.anyoneCanCheck)
        XCTAssertTrue(saved.isPinnedShopping)
        XCTAssertTrue(fixture.analytics.names.isEmpty)
    }

    func testTheTaskEditorFilesANewTaskInTheChosenFolder() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let model = TaskEditorViewModel(
            task: nil,
            folderId: fixture.shopping.id,
            context: fixture.context,
            repository: fixture.controller.repositories.tasks,
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: fixture.analytics
        )
        await model.loadFolders()
        model.title = "Sourdough"

        XCTAssertEqual(model.folderTitle, "Shopping")
        XCTAssertEqual(model.titlePlaceholder, FolderTemplate.shopping.itemPlaceholder)
        let didSave = await model.save()
        XCTAssertTrue(didSave)

        let stored = try await fixture.controller.repositories.tasks.tasks(
            TaskQuery(spaceId: fixture.space.id, folder: .folder(fixture.shopping.id))
        )
        XCTAssertTrue(stored.contains { $0.title == "Sourdough" })
        XCTAssertEqual(fixture.analytics.events, [.taskCreated(hasFolder: true, assignee: .nobody)])
    }

    func testTheTaskEditorMovesAnExistingTaskBetweenFolders() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let tasks = fixture.controller.repositories.tasks
        let inShopping = try await tasks.tasks(
            TaskQuery(spaceId: fixture.space.id, folder: .folder(fixture.shopping.id))
        )
        let coffee = try XCTUnwrap(inShopping.first)
        let model = TaskEditorViewModel(
            task: coffee,
            context: fixture.context,
            repository: tasks,
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: fixture.analytics
        )
        model.folderId = nil

        let didSave = await model.save()
        XCTAssertTrue(didSave)

        let reloaded = try await tasks.task(id: coffee.id)
        let stored = try XCTUnwrap(reloaded)
        XCTAssertNil(stored.folderId)
        XCTAssertTrue(fixture.analytics.names.isEmpty)
    }

    func testTheTaskEditorStoresAndClearsAPlace() async throws {
        let fixture = try await TasksFixture.make(now: now)
        let tasks = fixture.controller.repositories.tasks
        let created = try await tasks.create(
            TaskDraft(spaceId: fixture.space.id, title: "Time Out Market", createdByMemberId: fixture.me.id)
        )
        let model = TaskEditorViewModel(
            task: created,
            context: fixture.context,
            repository: tasks,
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: fixture.analytics
        )
        model.place = MapPlace(
            name: "Time Out Market",
            address: "Av. 24 de Julho, Lisbon",
            latitude: 38.7067,
            longitude: -9.1459
        )
        let didSave = await model.save()
        XCTAssertTrue(didSave)

        let withPlace = try await tasks.task(id: created.id)
        let placed = try XCTUnwrap(withPlace)
        XCTAssertTrue(placed.hasPlace)
        XCTAssertEqual(placed.address, "Av. 24 de Julho, Lisbon")

        let clearing = TaskEditorViewModel(
            task: placed,
            context: fixture.context,
            repository: tasks,
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: fixture.analytics
        )
        XCTAssertEqual(clearing.place?.name, "Time Out Market")
        clearing.place = nil
        let didClear = await clearing.save()
        XCTAssertTrue(didClear)

        let withoutPlace = try await tasks.task(id: created.id)
        let cleared = try XCTUnwrap(withoutPlace)
        XCTAssertFalse(cleared.hasPlace)
        XCTAssertNil(cleared.placeName)
    }
}
