import Foundation

public struct VoteResponses: Codable, Sendable, Equatable {
    public private(set) var byMember: [String: [Int]]

    public init(byMember: [String: [Int]] = [:]) {
        self.byMember = byMember
    }

    public var memberCount: Int { byMember.count }

    public var answeredMemberIds: [UUID] {
        byMember.keys.compactMap(UUID.init(uuidString:))
    }

    public subscript(memberId: UUID) -> [Int]? {
        get { byMember[memberId.uuidString] }
        set { byMember[memberId.uuidString] = newValue }
    }

    public func hasAnswered(_ memberId: UUID) -> Bool {
        byMember[memberId.uuidString] != nil
    }

    public func matches(optionCount: Int) -> [Int] {
        guard byMember.isEmpty == false else { return [] }
        let sets = byMember.values.map { Set($0) }
        guard var shared = sets.first else { return [] }
        for set in sets.dropFirst() {
            shared.formIntersection(set)
        }
        return shared.filter { $0 >= 0 && $0 < optionCount }.sorted()
    }
}
