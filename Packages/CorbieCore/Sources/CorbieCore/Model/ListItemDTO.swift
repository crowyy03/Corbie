import Foundation

public struct ListItemDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var listId: UUID?
    public var title: String
    public var isChecked: Bool
    public var checkedByMemberId: UUID?
    public var checkedAt: Date?
    public var addedByMemberId: UUID?
    public var note: String?
    public var placeName: String?
    public var address: String?
    public var latitude: Double?
    public var longitude: Double?
    public var sortIndex: Int

    public init(
        id: UUID,
        listId: UUID? = nil,
        title: String = "",
        isChecked: Bool = false,
        checkedByMemberId: UUID? = nil,
        checkedAt: Date? = nil,
        addedByMemberId: UUID? = nil,
        note: String? = nil,
        placeName: String? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.listId = listId
        self.title = title
        self.isChecked = isChecked
        self.checkedByMemberId = checkedByMemberId
        self.checkedAt = checkedAt
        self.addedByMemberId = addedByMemberId
        self.note = note
        self.placeName = placeName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.sortIndex = sortIndex
    }

    public init(_ item: ListItem) {
        self.init(
            id: item.id ?? UUID(),
            listId: item.list?.id,
            title: item.title ?? "",
            isChecked: item.isChecked,
            checkedByMemberId: item.checkedByMemberId,
            checkedAt: item.checkedAt,
            addedByMemberId: item.addedByMemberId,
            note: item.note,
            placeName: item.placeName,
            address: item.address,
            latitude: item.latitude?.doubleValue,
            longitude: item.longitude?.doubleValue,
            sortIndex: Int(item.sortIndex)
        )
    }

    public var hasPlace: Bool { latitude != nil && longitude != nil }
}
