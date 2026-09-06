import Foundation

public struct DataExportDocument: Sendable, Codable, Equatable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var space: SpaceDTO
    public var members: [MemberDTO]
    public var tasks: [TaskDTO]
    public var events: [EventDTO]
    public var eventComments: [EventCommentDTO]
    public var wishes: [WishDTO]
    public var plans: [PlanDTO]
    public var expenses: [PlanExpenseDTO]
    public var planSteps: [PlanStepDTO]
    public var lists: [ChecklistListDTO]
    public var listItems: [ListItemDTO]
    public var busyIntervals: [BusyIntervalDTO]
    public var capsules: [CapsuleDTO]
    public var votes: [VoteDTO]
    public var people: [PersonDTO]
    public var giftIdeas: [GiftIdeaDTO]

    public init(
        formatVersion: Int = DataExportDocument.currentFormatVersion,
        exportedAt: Date,
        space: SpaceDTO,
        members: [MemberDTO] = [],
        tasks: [TaskDTO] = [],
        events: [EventDTO] = [],
        eventComments: [EventCommentDTO] = [],
        wishes: [WishDTO] = [],
        plans: [PlanDTO] = [],
        expenses: [PlanExpenseDTO] = [],
        planSteps: [PlanStepDTO] = [],
        lists: [ChecklistListDTO] = [],
        listItems: [ListItemDTO] = [],
        busyIntervals: [BusyIntervalDTO] = [],
        capsules: [CapsuleDTO] = [],
        votes: [VoteDTO] = [],
        people: [PersonDTO] = [],
        giftIdeas: [GiftIdeaDTO] = []
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.space = space
        self.members = members
        self.tasks = tasks
        self.events = events
        self.eventComments = eventComments
        self.wishes = wishes
        self.plans = plans
        self.expenses = expenses
        self.planSteps = planSteps
        self.lists = lists
        self.listItems = listItems
        self.busyIntervals = busyIntervals
        self.capsules = capsules
        self.votes = votes
        self.people = people
        self.giftIdeas = giftIdeas
    }

    public var entityCount: Int {
        1 + members.count + tasks.count + events.count + eventComments.count + wishes.count
            + plans.count + expenses.count + planSteps.count + lists.count + listItems.count
            + busyIntervals.count + capsules.count + votes.count + people.count + giftIdeas.count
    }
}

public struct DataExport: Sendable {
    private let controller: PersistenceController

    public init(controller: PersistenceController) {
        self.controller = controller
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func document(spaceId: UUID, now: Date = Date()) async throws -> DataExportDocument {
        let repositories = controller.repositories
        guard let space = try await repositories.spaces.space(id: spaceId) else {
            throw CorbieError.notFound("space " + spaceId.uuidString)
        }
        let events = try await repositories.events.events(spaceId: spaceId)
        var eventComments: [EventCommentDTO] = []
        for event in events where event.commentCount > 0 {
            eventComments.append(contentsOf: try await repositories.events.comments(eventId: event.id))
        }
        let plans = try await repositories.plans.plans(
            spaceId: spaceId,
            statuses: PlanStatus.allCases
        )
        var expenses: [PlanExpenseDTO] = []
        var planSteps: [PlanStepDTO] = []
        for plan in plans {
            expenses.append(contentsOf: try await repositories.plans.expenses(planId: plan.id))
            planSteps.append(contentsOf: try await repositories.plans.steps(planId: plan.id))
        }
        let lists = try await repositories.lists.lists(spaceId: spaceId)
        var listItems: [ListItemDTO] = []
        for list in lists {
            listItems.append(contentsOf: try await repositories.lists.items(listId: list.id))
        }
        let busyIntervals = try await repositories.busyIntervals.intervals(
            spaceId: spaceId,
            from: .distantPast,
            to: .distantFuture
        )
        let people = try await repositories.people.people(spaceId: spaceId)
        var giftIdeas: [GiftIdeaDTO] = []
        for person in people {
            giftIdeas.append(contentsOf: try await repositories.people.giftIdeas(personId: person.id))
        }
        let wishes = try await repositories.wishes.wishes(WishQuery(spaceId: spaceId, fulfilled: nil))
        return DataExportDocument(
            exportedAt: now,
            space: space,
            members: try await repositories.members.members(spaceId: spaceId),
            tasks: try await repositories.tasks.tasks(TaskQuery(spaceId: spaceId, done: .any, includeArchived: true)),
            events: events,
            eventComments: eventComments,
            wishes: wishes.map(DataExport.stripBinary),
            plans: plans,
            expenses: expenses,
            planSteps: planSteps,
            lists: lists,
            listItems: listItems,
            busyIntervals: busyIntervals,
            capsules: try await repositories.capsules.capsules(spaceId: spaceId),
            votes: try await repositories.votes.votes(spaceId: spaceId),
            people: people,
            giftIdeas: giftIdeas
        )
    }

    public func data(spaceId: UUID, now: Date = Date()) async throws -> Data {
        let document = try await document(spaceId: spaceId, now: now)
        do {
            return try DataExport.encoder().encode(document)
        } catch {
            throw CorbieError.invalidInput(error.localizedDescription)
        }
    }

    public func write(spaceId: UUID, to directory: URL? = nil, now: Date = Date()) async throws -> URL {
        let payload = try await data(spaceId: spaceId, now: now)
        let folder = directory ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = folder.appendingPathComponent(DataExport.fileName(now: now))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try payload.write(to: url, options: .atomic)
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
        return url
    }

    public static func fileName(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "corbie-export-" + formatter.string(from: now) + ".json"
    }

    private static func stripBinary(_ wish: WishDTO) -> WishDTO {
        var copy = wish
        copy.localImage = nil
        return copy
    }
}
