import Foundation

struct FieldChanges<DTO: Identifiable> {
    let edited: DTO
    let original: DTO

    init(_ edited: DTO, from original: DTO) throws {
        guard edited.id == original.id else {
            throw CorbieError.invalidInput("the edited copy and the original are different rows")
        }
        self.edited = edited
        self.original = original
    }

    func changed<Value: Equatable>(_ field: KeyPath<DTO, Value>) -> Bool {
        edited[keyPath: field] != original[keyPath: field]
    }

    func write<Value: Equatable>(_ field: KeyPath<DTO, Value>, _ assign: (Value) -> Void) {
        guard changed(field) else { return }
        assign(edited[keyPath: field])
    }
}

extension FieldChanges: Sendable where DTO: Sendable {}
