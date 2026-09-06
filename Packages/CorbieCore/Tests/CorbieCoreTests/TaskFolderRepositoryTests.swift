import Foundation
import Testing
@testable import CorbieCore

@Suite struct TaskFolderRepositoryTests {
    @Test func foldersListThePinnedShoppingOneFirstThenBySortIndex() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let places = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Places", template: .places)
        )
        let watch = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "To watch", template: .watch)
        )
        let shopping = try await repository.pinnedShoppingFolder(spaceId: world.space.id, title: "Shopping")

        let folders = try await repository.folders(spaceId: world.space.id)
        #expect(folders.map(\.id) == [shopping.id, places.id, watch.id])
        #expect(folders.first?.template == .shopping)
    }

    @Test func thePinnedShoppingFolderIsCreatedOnceAndReused() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let first = try await repository.pinnedShoppingFolder(
            spaceId: world.space.id,
            title: "Shopping",
            createdByMemberId: world.me.id
        )
        let second = try await repository.pinnedShoppingFolder(spaceId: world.space.id, title: "Groceries")
        #expect(first.id == second.id)
        #expect(second.title == "Shopping")
        let folders = try await repository.folders(spaceId: world.space.id)
        #expect(folders.count == 1)
    }

    @Test func deletingAFolderKeepsItsTasksAsPlainOnes() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Places", template: .places)
        )
        let task = try await repository.create(
            TaskDraft(spaceId: world.space.id, title: "Belem", folderId: folder.id)
        )
        try await repository.deleteFolder(id: folder.id)

        let stored = try await repository.task(id: task.id)
        #expect(stored?.folderId == nil)
        let gone = try await repository.folder(id: folder.id)
        #expect(gone == nil)
        let plain = try await repository.tasks(TaskQuery(spaceId: world.space.id))
        #expect(plain.map(\.title) == ["Belem"])
    }

    @Test func theFolderFilterSplitsPlainTasksFromFolderTasks() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Shopping", template: .shopping)
        )
        _ = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Call the vet"))
        _ = try await repository.create(
            TaskDraft(spaceId: world.space.id, title: "Milk", folderId: folder.id)
        )

        let plain = try await repository.tasks(TaskQuery(spaceId: world.space.id, folder: .none))
        let inFolder = try await repository.tasks(TaskQuery(spaceId: world.space.id, folder: .folder(folder.id)))
        let everything = try await repository.tasks(TaskQuery(spaceId: world.space.id, folder: .all))
        #expect(plain.map(\.title) == ["Call the vet"])
        #expect(inFolder.map(\.title) == ["Milk"])
        #expect(everything.count == 2)
        let titles = Set(everything.map(\.title))
        #expect(titles == ["Call the vet", "Milk"])
    }

    @Test func countsFollowTheFolderFilter() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Shopping", template: .shopping)
        )
        _ = try await repository.create(
            TaskDraft(spaceId: world.space.id, title: "Mine", assigneeMemberId: world.me.id)
        )
        _ = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Free"))
        _ = try await repository.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Milk",
                assigneeMemberId: world.me.id,
                folderId: folder.id
            )
        )

        let plain = try await repository.counts(
            spaceId: world.space.id,
            memberId: world.me.id,
            partnerId: world.partner.id
        )
        #expect(plain == TaskCounts(all: 2, mine: 1, partner: 0, free: 1))
        let shopping = try await repository.counts(
            spaceId: world.space.id,
            memberId: world.me.id,
            partnerId: world.partner.id,
            folder: .folder(folder.id)
        )
        #expect(shopping == TaskCounts(all: 1, mine: 1, partner: 0, free: 0))
    }

    @Test func movingATaskChangesItsFolderAndReordersWriteSortIndex() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Shopping", template: .shopping)
        )
        let milk = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Milk"))
        let bread = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Bread"))

        _ = try await repository.move(taskId: milk.id, toFolder: folder.id)
        _ = try await repository.move(taskId: bread.id, toFolder: folder.id)
        let reordered = try await repository.reorder(taskIds: [bread.id, milk.id])
        #expect(reordered.map(\.sortIndex) == [0, 1])

        let stored = try await repository.tasks(TaskQuery(spaceId: world.space.id, folder: .folder(folder.id)))
        #expect(stored.map(\.title) == ["Bread", "Milk"])

        _ = try await repository.move(taskId: milk.id, toFolder: nil)
        let unfiled = try await repository.task(id: milk.id)
        #expect(unfiled?.folderId == nil)
    }

    @Test func clearDoneRemovesOnlyTickedTasksOfThatFolder() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(spaceId: world.space.id, title: "Shopping", template: .shopping)
        )
        let milk = try await repository.create(
            TaskDraft(spaceId: world.space.id, title: "Milk", folderId: folder.id)
        )
        _ = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Bread", folderId: folder.id))
        let plain = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Call the vet"))
        _ = try await repository.markDone(taskId: milk.id, memberId: world.me.id)
        _ = try await repository.markDone(taskId: plain.id, memberId: world.me.id)

        let remaining = try await repository.clearDone(folderId: folder.id)
        #expect(remaining.map(\.title) == ["Bread"])
        let keptPlain = try await repository.task(id: plain.id)
        #expect(keptPlain != nil)
    }

    @Test func onlyTheAuthorTicksWhenTheFolderSaysSo() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let folder = try await repository.createFolder(
            TaskFolderDraft(
                spaceId: world.space.id,
                title: "To watch",
                template: .watch,
                anyoneCanCheck: false,
                createdByMemberId: world.me.id
            )
        )
        let task = try await repository.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Stalker",
                folderId: folder.id,
                createdByMemberId: world.me.id
            )
        )
        await #expect(throws: CorbieError.self) {
            _ = try await repository.markDone(taskId: task.id, memberId: world.partner.id)
        }
        let done = try await repository.markDone(taskId: task.id, memberId: world.me.id)
        #expect(done.task.isDone)
    }

    @Test func placeFieldsSurviveCreateAndUpdate() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        var task = try await repository.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Time Out Market",
                placeName: "Time Out Market",
                address: "Av. 24 de Julho 49",
                lat: 38.706,
                lon: -9.145
            )
        )
        #expect(task.hasPlace)
        #expect(task.address == "Av. 24 de Julho 49")

        task.placeName = "Mercado da Ribeira"
        task.lat = nil
        task.lon = nil
        let updated = try await repository.update(task)
        #expect(updated.placeName == "Mercado da Ribeira")
        #expect(updated.hasPlace == false)
    }
}
