import Foundation
import RangeState
import Testing

struct RangeInvalidationBufferTests {
	@Test func invalidationRaisedWhileFlushingIsDelivered() {
		let buffer = RangeInvalidationBuffer()
		let initial = RangeTarget.set(IndexSet(integersIn: 0..<22))
		let nested = RangeTarget.set(IndexSet(integersIn: 15..<21))
		var delivered: [RangeTarget] = []
		buffer.invalidationHandler = { target in
			delivered.append(target)
			if delivered.count == 1 {
				buffer.invalidate(nested)
			}
		}

		buffer.beginBuffering()
		buffer.invalidate(initial)
		buffer.endBuffering()

		#expect(delivered == [initial, nested])
	}

	@Test func bufferingScopeOpenedByHandlerSurvivesOuterFlush() {
		let buffer = RangeInvalidationBuffer()
		let initial = RangeTarget.range(NSRange(location: 0, length: 22))
		let nested = RangeTarget.range(NSRange(location: 30, length: 5))
		var delivered: [RangeTarget] = []
		buffer.invalidationHandler = { target in
			delivered.append(target)
			if delivered.count == 1 {
				buffer.beginBuffering()
				buffer.invalidate(nested)
			}
		}

		buffer.beginBuffering()
		buffer.invalidate(initial)
		buffer.endBuffering()
		#expect(delivered == [.set(IndexSet(integersIn: 0..<22))])

		buffer.endBuffering()
		#expect(delivered == [.set(IndexSet(integersIn: 0..<22)), .set(IndexSet(integersIn: 30..<35))])
	}

	@Test func nestedDepthFlushesOnlyAfterFinalEnd() {
		let buffer = RangeInvalidationBuffer()
		var delivered: [RangeTarget] = []
		buffer.invalidationHandler = { delivered.append($0) }

		buffer.beginBuffering()
		buffer.beginBuffering()
		buffer.invalidate(.range(NSRange(location: 0, length: 22)))
		buffer.endBuffering()
		#expect(delivered.isEmpty)
		buffer.invalidate(.range(NSRange(location: 30, length: 5)))
		buffer.endBuffering()
		#expect(delivered == [.set(IndexSet(integersIn: 0..<22).union(IndexSet(integersIn: 30..<35)))])
	}
}
