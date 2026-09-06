import Foundation

public struct Repositories: Sendable {
    public let spaces: any SpaceRepository
    public let members: any MemberRepository
    public let tasks: any TaskRepository
    public let events: any EventRepository
    public let wishes: any WishRepository
    public let goals: any GoalRepository
    public let busyIntervals: any BusyIntervalRepository
    public let capsules: any CapsuleRepository
    public let votes: any VoteRepository
    public let people: any PeopleRepository

    public init(stack: CoreDataStack) {
        spaces = CoreDataSpaceRepository(stack: stack)
        members = CoreDataMemberRepository(stack: stack)
        tasks = CoreDataTaskRepository(stack: stack)
        events = CoreDataEventRepository(stack: stack)
        wishes = CoreDataWishRepository(stack: stack)
        goals = CoreDataGoalRepository(stack: stack)
        busyIntervals = CoreDataBusyIntervalRepository(stack: stack)
        capsules = CoreDataCapsuleRepository(stack: stack)
        votes = CoreDataVoteRepository(stack: stack)
        people = CoreDataPeopleRepository(stack: stack)
    }
}
