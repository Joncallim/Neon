import Foundation
import Rearrange
import RangeState
import Testing

@MainActor
@Suite(.serialized)
struct InitialFillMutationTests {
    @Test func initialFillHeldWhenEditArrives() {
        var length = 4500
        var seen = 0
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { _, completion in
            seen += 1
            held.append(completion)
        }))
        #expect(!processor.processLocation(4499, mode: .required))
        #expect(processor.processedUpperBound == 0)
        #expect(seen == 1)
        length += 1
        processor.didChangeContent(in: NSRange(location: 50, length: 0), delta: 1)
        #expect(seen == 2, "the edit reaches the handler while the initial fill is held")
        held[0]()
        #expect(processor.processedUpperBound == 4500)
        held[1]()
        #expect(processor.processedUpperBound == 4501)
    }

    @Test func initialFillCompletedBeforeTheSameEdit() {
        var length = 4500
        var seen = 0
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { _, completion in
            seen += 1
            completion()
        }))
        #expect(processor.processLocation(4499, mode: .required))
        #expect(processor.processedUpperBound == 4500)
        #expect(seen == 1)
        length += 1
        processor.didChangeContent(in: NSRange(location: 50, length: 0), delta: 1)
        #expect(seen == 2, "the edit reaches the handler after initial fill completed")
    }

    @Test func anEditOutsideTheEffectivePrefixAfterAPendingDeletionIsIgnored() {
        var length = 1000
        var seen = 0
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { _, completion in
            seen += 1
            if seen == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(99, mode: .required))
        #expect(processor.processedUpperBound == 100)
        length -= 90
        processor.didChangeContent(in: NSRange(location: 0, length: 90), delta: -90)
        #expect(seen == 2)
        length -= 1
        processor.didChangeContent(in: NSRange(location: 50, length: 1), delta: -1)
        #expect(seen == 2, "the second edit lies outside the pending deletion's effective prefix of 10")
        held[0]()
        #expect(processor.processedUpperBound == 10)
    }

    @Test func aPartialFillTracksCoveredEditsButIgnoresEditsBeyondIt() {
        var length = 1000
        var seen = 0
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { _, completion in
            seen += 1
            if seen == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(99, mode: .required))
        #expect(!processor.processLocation(299, mode: .required))
        #expect(seen == 2)
        length += 1
        processor.didChangeContent(in: NSRange(location: 150, length: 0), delta: 1)
        #expect(seen == 3, "the pending fill covers this edit")
        length += 1
        processor.didChangeContent(in: NSRange(location: 350, length: 0), delta: 1)
        #expect(seen == 3, "the pending fill does not cover this later location")
        held[0]()
        held[1]()
        #expect(processor.processedUpperBound == 301)
    }

    @Test func heldInitialFillTracksSeveralEditsInOrder() {
        var length = 4500
        var observed: [RangeMutation] = []
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { mutation, completion in
            observed.append(mutation)
            held.append(completion)
        }))
        #expect(!processor.processLocation(4499, mode: .required))
        length += 1
        processor.didChangeContent(in: NSRange(location: 50, length: 0), delta: 1)
        length -= 2
        processor.didChangeContent(in: NSRange(location: 51, length: 2), delta: -2)
        length += 1
        processor.didChangeContent(in: NSRange(location: 4499, length: 0), delta: 1)
        length += 1
        processor.didChangeContent(in: NSRange(location: 4498, length: 0), delta: 1)
        #expect(observed.count == 4)
        #expect(observed.map(\.range) == [NSRange(location: 0, length: 0), NSRange(location: 50, length: 0), NSRange(location: 51, length: 2), NSRange(location: 4498, length: 0)])
        #expect(observed.map(\.delta) == [4500, 1, -2, 1])
        #expect(observed.map(\.postApplyLimit) == [4500, 4501, 4499, 4500])
        for completion in held { completion() }
        #expect(processor.processedUpperBound == 4500)
    }

    @Test func pendingDeletionClipsStraddlingEditAtEffectiveBoundary() {
        var length = 100
        var observed: [RangeMutation] = []
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { mutation, completion in
            observed.append(mutation)
            if observed.count == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(99, mode: .required))
        length -= 90
        processor.didChangeContent(in: NSRange(location: 0, length: 90), delta: -90)
        length += 1
        processor.didChangeContent(in: NSRange(location: 10, length: 0), delta: 1)
        length += 1
        processor.didChangeContent(in: NSRange(location: 9, length: 0), delta: 1)
        length -= 4
        processor.didChangeContent(in: NSRange(location: 8, length: 4), delta: -4)
        #expect(observed.count == 4)
        #expect(observed.map(\.range) == [NSRange(location: 0, length: 0), NSRange(location: 0, length: 90), NSRange(location: 9, length: 0), NSRange(location: 8, length: 3)])
        #expect(observed.map(\.delta) == [100, -90, 1, -3])
        #expect(observed.map(\.postApplyLimit) == [100, 10, 11, 8])
        for completion in held { completion() }
        #expect(processor.processedUpperBound == 8)
    }

    @Test func deletionToEmptyFollowedByInsertionRemainsVisible() {
        var length = 10
        var observed: [RangeMutation] = []
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { mutation, completion in
            observed.append(mutation)
            if observed.count == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(9, mode: .required))
        length = 0
        processor.didChangeContent(in: NSRange(location: 0, length: 10), delta: -10)
        length = 1
        processor.didChangeContent(in: NSRange(location: 0, length: 0), delta: 1)
        #expect(observed.count == 3)
        #expect(observed.map(\.postApplyLimit) == [10, 0, 1])
        for completion in held { completion() }
        #expect(processor.processedUpperBound == 1)
    }

    @Test func insertionAtZeroAfterPrefixDeletionProcessesFirstCharacterOfUnprocessedSuffix() {
        var length = 100
        var observed: [RangeMutation] = []
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { mutation, completion in
            observed.append(mutation)
            if observed.count == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(9, mode: .required))
        length -= 10
        processor.didChangeContent(in: NSRange(location: 0, length: 10), delta: -10)
        length += 1
        processor.didChangeContent(in: NSRange(location: 0, length: 0), delta: 1)
        #expect(observed.map(\.range) == [NSRange(location: 0, length: 0), NSRange(location: 0, length: 10), NSRange(location: 0, length: 0)])
        #expect(observed.map(\.postApplyLimit) == [10, 0, 1])
        for completion in held { completion() }
        #expect(processor.processedUpperBound == 1)
    }

    @Test(arguments: [(-4, 8), (-2, 10), (-1, 11)])
    func replacementStraddlingThePendingBoundaryClipsItsVisibleLength(delta: Int, expectedBound: Int) {
        var length = 1000
        var observed: [RangeMutation] = []
        var held: [() -> Void] = []
        let processor = RangeProcessor(configuration: .init(lengthProvider: { length }, changeHandler: { mutation, completion in
            observed.append(mutation)
            if observed.count == 1 { completion() } else { held.append(completion) }
        }))
        #expect(processor.processLocation(99, mode: .required))
        length -= 89
        processor.didChangeContent(in: NSRange(location: 0, length: 89), delta: -89)
        length += delta
        processor.didChangeContent(in: NSRange(location: 8, length: 4), delta: delta)
        #expect(observed.count == 3)
        #expect(observed[2].range == NSRange(location: 8, length: 3))
        #expect(observed[2].delta == expectedBound - 11)
        #expect(observed[2].postApplyLimit == expectedBound)
        for completion in held { completion() }
        #expect(processor.processedUpperBound == expectedBound)
    }
}
