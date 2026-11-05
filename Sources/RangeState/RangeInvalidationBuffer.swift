import Foundation

public final class RangeInvalidationBuffer {
	public typealias Handler = (RangeTarget) -> Void

	private enum State: Hashable {
		case idle
		case buffering(RangeTarget, Int)
	}

	private var state = State.idle
	public var invalidationHandler: Handler = { _ in }

	public init() {
	}
}

extension RangeInvalidationBuffer {
	public func beginBuffering() {
		switch state {
		case .idle:
			self.state = .buffering(.set(IndexSet()), 1)
		case let .buffering(set, count):
			self.state = .buffering(set, count + 1)
		}
	}

	public func endBuffering() {
		switch state {
		case .idle:
			preconditionFailure()
		case let .buffering(set, 1):
			self.state = .idle
			// The handler may invalidate another range or open a new buffering scope.
			// Publish this batch only after leaving the old scope, so that work is not lost.
			invalidationHandler(set)
		case let .buffering(set, count):
			precondition(count > 1)
			self.state = .buffering(set, count - 1)
		}
	}

	/// Shift retained dirty source through an edit before buffering its new invalidations.
	/// The range describes the original text replaced by the edit.
	package func contentChanged(in range: NSRange, delta: Int) {
		guard case let .buffering(target, count) = state else { return }
		let existing: IndexSet
		switch target {
		case .all:
			return
		case let .set(set):
			existing = set
		case let .range(dirty):
			existing = IndexSet(integersIn: dirty.location..<(dirty.location + dirty.length))
		}

		let oldEnd = range.location + range.length
		let newEnd = oldEnd + delta
		precondition(newEnd >= range.location)
		let edited = range.location..<oldEnd
		var shifted = IndexSet()
		for dirty in existing.rangeView {
			if dirty.lowerBound < range.location {
				shifted.insert(integersIn: dirty.lowerBound..<min(dirty.upperBound, range.location))
			}
			if dirty.upperBound > oldEnd {
				shifted.insert(integersIn: (max(dirty.lowerBound, oldEnd) + delta)..<(dirty.upperBound + delta))
			}
			// Repaint replacement text that touches previously dirty source.
			// Split around deletions so a surviving tail cannot disappear.
			if newEnd > range.location && (dirty.overlaps(edited) || (range.length == 0 && dirty.contains(range.location))) {
				shifted.insert(integersIn: range.location..<newEnd)
			}
		}
		state = .buffering(.set(shifted), count)
	}

	public func invalidate(_ target: RangeTarget) {
		switch state {
		case .idle:
			invalidationHandler(target)
		case let .buffering(existing, count):
			precondition(count > 0)

			self.state = .buffering(existing.union(target), count)
		}
	}
}
