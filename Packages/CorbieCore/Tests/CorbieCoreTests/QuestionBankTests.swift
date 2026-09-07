import Foundation
import Testing
@testable import CorbieCore

@Suite struct QuestionBankTests {
    private static let idPattern = try? NSRegularExpression(pattern: "^q[0-9]{4}$")

    private func files(in directory: URL?) -> [URL] {
        guard let directory else { return [] }
        let found = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return found.filter { $0.pathExtension.lowercased() == "json" }.sorted { $0.path < $1.path }
    }

    private func write(_ json: String, named name: String) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-questions-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent(name))
        return directory
    }

    @Test func everyBundledFileMatchesTheSchema() throws {
        let decoder = JSONDecoder()
        var seen: Set<String> = []
        for file in files(in: QuestionBank.bundledDirectory) {
            let data = try Data(contentsOf: file)
            let entries = try decoder.decode([QuestionBankEntry].self, from: data)
            #expect(entries.isEmpty == false, "\(file.lastPathComponent) has no questions")
            for entry in entries {
                let range = NSRange(entry.id.startIndex..., in: entry.id)
                let matches = QuestionBankTests.idPattern?.numberOfMatches(in: entry.id, range: range) ?? 0
                #expect(matches == 1, "\(entry.id) is not a q0000 identifier")
                #expect(seen.insert(entry.id).inserted, "\(entry.id) appears twice")
                #expect(entry.text.count == QuestionBankEntry.languages.count, "\(entry.id) misses a language")
                let english = entry.text["en"] ?? ""
                #expect(english.count <= QuestionBankEntry.maxEnglishLength, "\(entry.id) is longer than one line")
                for language in QuestionBankEntry.languages {
                    let text = entry.text[language] ?? ""
                    #expect(text.isEmpty == false, "\(entry.id) has no \(language) text")
                    #expect(text.contains("!") == false, "\(entry.id) [\(language)] shouts")
                    #expect(text.contains("\u{2014}") == false, "\(entry.id) [\(language)] uses an em dash")
                }
            }
        }
        #expect(QuestionBank.bundled.entries.count == seen.count)
    }

    @Test func theBankIsSortedAndAddressableById() {
        let bank = QuestionBank.bundled
        #expect(bank.questionIds == bank.questionIds.sorted())
        for id in bank.questionIds.prefix(5) {
            #expect(bank.entry(id: id)?.id == id)
        }
        #expect(bank.entry(id: "q9999") == nil)
    }

    @Test func anEmptyDirectoryLoadsAnEmptyBank() throws {
        let directory = try write("[]", named: "empty.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.removeItem(at: directory.appendingPathComponent("empty.json"))
        #expect(QuestionBank.load(from: directory).isEmpty)
        #expect(QuestionBank.load(from: nil).isEmpty)
    }

    @Test func everyThemeFileIsMergedIntoOneBank() throws {
        let first = """
        [{"id":"q0001","theme":"memories","stage":"any","tone":"light","text":{"en":"a","de":"a","es":"a","fr":"a","it":"a"}}]
        """
        let directory = try write(first, named: "memories.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let second = """
        [{"id":"q0002","theme":"future","stage":"2y+","tone":"deep","text":{"en":"b","de":"b","es":"b","fr":"b","it":"b"}}]
        """
        try Data(second.utf8).write(to: directory.appendingPathComponent("future.json"))
        let bank = QuestionBank.load(from: directory)
        #expect(bank.questionIds == ["q0001", "q0002"])
        #expect(bank.entry(id: "q0002")?.stage == .twoYears)
    }

    @Test func aBrokenFileIsSkippedInsteadOfCrashing() throws {
        let directory = try write("{ not json", named: "broken.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let good = """
        [{"id":"q0003","theme":"playful","stage":"6m+","tone":"playful","text":{"en":"c","de":"c","es":"c","fr":"c","it":"c"}}]
        """
        try Data(good.utf8).write(to: directory.appendingPathComponent("playful.json"))
        let bank = QuestionBank.load(from: directory)
        #expect(bank.questionIds == ["q0003"])
    }
}
