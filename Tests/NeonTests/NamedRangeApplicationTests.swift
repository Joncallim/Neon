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
        #expect(mapped.tokens.map(\.range) == captures.map(\.range))
        #expect(mapped.tokens.map(\.name) == ["outer", "nested", "outside", "empty"])
        var semantic: [Token] = []
        var painted: [NSRange] = []
        mapped.forEachTokenToApply { token, range in semantic.append(token); painted.append(range) }
        #expect(semantic == Array(mapped.tokens.prefix(2)))
        #expect(painted == [range, NSRange(location: 4, length: 2)])
        let plain = TokenApplication(namedRanges: captures, range: range)
        #expect(plain.tokens.map(\.name) == ["wide", "nested", "outside", "empty"])
        #expect(plain.tokens.map(\.range) == mapped.tokens.map(\.range))
        let empty = TokenApplication(namedRanges: captures, range: NSRange(location: 5, length: 0))
        var calls = 0
        empty.forEachTokenToApply { _, _ in calls += 1 }
        #expect(calls == 0)
        #expect(empty.range == NSRange(location: 5, length: 0))
        let unbounded = TokenApplication(tokens: Array(mapped.tokens.prefix(2)))
        var unboundedRanges: [NSRange] = []
        unbounded.forEachTokenToApply { _, range in unboundedRanges.append(range) }
        #expect(unboundedRanges == Array(mapped.tokens.prefix(2)).map(\.range))
    }
}
