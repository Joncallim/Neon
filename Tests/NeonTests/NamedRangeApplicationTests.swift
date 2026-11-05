import Foundation
import SwiftTreeSitter
import Testing
#if canImport(Neon)
import Neon
#else
import OwnedStylingCore
#endif

struct NamedRangeApplicationTests {
    @Test func boundedTokensPreserveNamesOrderAndEmptyApplications() {
        func named(_ name: String, _ start: Int, _ length: Int) -> NamedRange {
            NamedRange(name: name, range: NSRange(location: start, length: length),
                       pointRange: Point(row: 0, column: start * 2)..<Point(row: 0, column: (start + length) * 2))
        }
        let captures = [named("wide", 0, 10), named("nested", 4, 2), named("outside", 20, 2), named("empty", 5, 0)]
        let range = NSRange(location: 3, length: 4)
        let mapped = TokenApplication(namedRanges: captures, nameMap: ["wide": "outer"], range: range)
        #expect(mapped.tokens == [Token(name: "outer", range: range), Token(name: "nested", range: NSRange(location: 4, length: 2))])
        let plain = TokenApplication(namedRanges: captures, range: range)
        #expect(plain.tokens.map(\.name) == ["wide", "nested"])
        #expect(plain.tokens.map(\.range) == mapped.tokens.map(\.range))
        let empty = TokenApplication(namedRanges: captures, range: NSRange(location: 5, length: 0))
        #expect(empty.tokens.isEmpty)
        #expect(empty.range == NSRange(location: 5, length: 0))
    }
}
