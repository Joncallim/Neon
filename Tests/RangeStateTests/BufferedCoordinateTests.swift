import Foundation
import RangeState
import Testing

@Suite("Buffered repaint coordinates", .serialized)
struct BufferedCoordinateTests {
    @Test func survivingDirtyTailMovesThroughDeletion() {
        let buffer = RangeInvalidationBuffer()
        var delivered: [RangeTarget] = []
        buffer.invalidationHandler = { delivered.append($0) }
        buffer.beginBuffering()
        buffer.invalidate(.range(NSRange(location: 10, length: 10)))
        buffer.contentChanged(in: NSRange(location: 0, length: 15), delta: -15)
        buffer.endBuffering()
        #expect(delivered == [.set(IndexSet(integersIn: 0..<5))])
    }

    @Test func eachEditTransformsOnlyPreviouslyBufferedInvalidations() {
        let buffer = RangeInvalidationBuffer()
        var delivered: [RangeTarget] = []
        buffer.invalidationHandler = { delivered.append($0) }
        buffer.beginBuffering()
        buffer.invalidate(.range(NSRange(location: 20, length: 5)))
        buffer.beginBuffering()
        buffer.contentChanged(in: NSRange(location: 0, length: 10), delta: -10)
        buffer.invalidate(.range(NSRange(location: 2, length: 2)))
        buffer.endBuffering()
        #expect(delivered.isEmpty)
        buffer.contentChanged(in: NSRange(location: 3, length: 0), delta: 2)
        buffer.invalidate(.range(NSRange(location: 0, length: 1)))
        buffer.endBuffering()
        #expect(delivered == [.set(IndexSet([0, 2, 3, 4, 5, 12, 13, 14, 15, 16]))])
    }

    @Test func allDocumentAndIdleScopesKeepTheirMeaning() {
        let buffer = RangeInvalidationBuffer()
        var delivered: [RangeTarget] = []
        buffer.invalidationHandler = { delivered.append($0) }
        buffer.contentChanged(in: NSRange(location: 0, length: 2), delta: 3)
        #expect(delivered.isEmpty)
        buffer.beginBuffering()
        buffer.invalidate(.all)
        buffer.contentChanged(in: NSRange(location: 0, length: 2), delta: -2)
        buffer.endBuffering()
        #expect(delivered == [.all])
    }

    @Test(.timeLimit(.minutes(1)))
    func allSmallEditsMatchIndependentCharacterIdentityOracle() {
        var scenarios = 0
        for length in 0...8 {
            for mask in 0..<(1 << length) {
                let flags = (0..<length).map { mask & (1 << $0) != 0 }
                let dirty = IndexSet(flags.indices.filter { flags[$0] })
                for start in 0...length {
                    for end in start...length {
                        for replacementLength in 0...3 {
                            let touchesDirty = flags[start..<end].contains(true) ||
                                (start == end && start < length && flags[start])
                            let expectedFlags = Array(flags[..<start]) +
                                Array(repeating: touchesDirty, count: replacementLength) + Array(flags[end...])
                            let expected = IndexSet(expectedFlags.indices.filter { expectedFlags[$0] })
                            let buffer = RangeInvalidationBuffer()
                            var actual: RangeTarget?
                            buffer.invalidationHandler = { actual = $0 }
                            buffer.beginBuffering()
                            buffer.invalidate(.set(dirty))
                            buffer.contentChanged(in: NSRange(start..<end), delta: replacementLength - (end - start))
                            buffer.endBuffering()
                            #expect(actual == .set(expected))
                            scenarios += 1
                        }
                    }
                }
            }
        }
        #expect(scenarios == 75772)
    }

    @Test func sparseLargeCoordinatesAndReentrantScopeSurvive() {
        let buffer = RangeInvalidationBuffer()
        var delivered: [RangeTarget] = []
        buffer.invalidationHandler = { target in
            delivered.append(target)
            if delivered.count == 1 {
                buffer.beginBuffering()
                buffer.invalidate(.range(NSRange(location: 4, length: 2)))
                buffer.contentChanged(in: NSRange(location: 0, length: 0), delta: 3)
            }
        }
        buffer.beginBuffering()
        buffer.invalidate(.range(NSRange(location: 10_000_000, length: 4)))
        buffer.contentChanged(in: NSRange(location: 0, length: 1_000_000), delta: -1_000_000)
        buffer.endBuffering()
        buffer.endBuffering()
        #expect(delivered == [.set(IndexSet(integersIn: 9_000_000..<9_000_004)), .set(IndexSet(integersIn: 7..<9))])
    }
}
