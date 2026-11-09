import Foundation
import Testing

@testable import TreeSitterClient

private actor QueueSubmissionGate {
	private let heldRequestID: Int
	private var heldEntered = false
	private var heldWaiter: CheckedContinuation<Void, Never>?
	private var heldRelease: CheckedContinuation<Void, Never>?
	private var followingEntered = false

	init(holding requestID: Int) {
		heldRequestID = requestID
	}

	func beforeQueueSubmission(_ requestID: Int) async {
		if requestID == heldRequestID {
			heldEntered = true
			heldWaiter?.resume()
			heldWaiter = nil
			await withCheckedContinuation { heldRelease = $0 }
		} else if requestID > heldRequestID {
			followingEntered = true
		}
	}

	func waitForHeld() async {
		if heldEntered { return }
		await withCheckedContinuation { heldWaiter = $0 }
	}

	func hasFollowingEntered() -> Bool { followingEntered }

	func releaseHeld() {
		heldRelease?.resume()
		heldRelease = nil
	}
}

struct BackgroundProcessorOrderTests {
	@MainActor
	@Test func synchronousPreferredCompletesBeforeReturningWhenIdle() {
		let processor = BackgroundProcessor(value: 1)
		var completions = [Int]()

		processor.accessValue(
			isolation: MainActor.shared, preferSynchronous: true,
			operation: { $0 + 1 }, completion: { result in
				switch result {
				case let .success(value): completions.append(value)
				case let .failure(error): Issue.record("operation failed: \(error)")
				}
			}
		)

		#expect(completions == [2])
		#expect(!processor.hasPendingWork)
	}

	@MainActor
	@Test func deferredMutationsCompleteInRequestOrderWhenFirstTaskIsHeld() async throws {
		let gate = QueueSubmissionGate(holding: 0)
		let processor = BackgroundProcessor(value: 1, beforeQueueSubmission: { requestID in
			await gate.beforeQueueSubmission(requestID)
		})
		var completions = [Int]()

		processor.accessValue(
			isolation: MainActor.shared, preferSynchronous: false,
			operation: { _ in 0 }, completion: { result in
				switch result {
				case let .success(value): completions.append(value)
				case let .failure(error): Issue.record("first operation failed: \(error)")
				}
			}
		)
		await gate.waitForHeld()
		processor.accessValue(
			isolation: MainActor.shared, preferSynchronous: true,
			operation: { _ in 1 }, completion: { result in
				switch result {
				case let .success(value): completions.append(value)
				case let .failure(error): Issue.record("second operation failed: \(error)")
				}
			}
		)

		// The first task is suspended before submitting to the serial queue.
		// A later request must not overtake it while that task is suspended.
		try await Task.sleep(for: .milliseconds(300))
		let secondEnteredBeforeFirstRelease = await gate.hasFollowingEntered()
		await gate.releaseHeld()
		let deadline = ContinuousClock.now + .seconds(5)
		while completions.count < 2 && ContinuousClock.now < deadline {
			try await Task.sleep(for: .milliseconds(10))
		}
		#expect(!secondEnteredBeforeFirstRelease)
		#expect(completions == [0, 1])
		#expect(!processor.hasPendingWork)
	}

	@MainActor
	@Test func laterRequestWaitsForTheActualTailWhileEarlierWorkCompletes() async throws {
		let gate = QueueSubmissionGate(holding: 1)
		let processor = BackgroundProcessor(value: 1, beforeQueueSubmission: { requestID in
			await gate.beforeQueueSubmission(requestID)
		})
		var completions = [Int]()
		for index in 0 ... 1 {
			processor.accessValue(
				isolation: MainActor.shared, preferSynchronous: false,
				operation: { _ in index }, completion: { result in
					switch result {
					case let .success(value): completions.append(value)
					case let .failure(error): Issue.record("operation failed: \(error)")
					}
				}
			)
		}
		await gate.waitForHeld()
		#expect(completions == [0])
		processor.accessValue(
			isolation: MainActor.shared, preferSynchronous: true,
			operation: { _ in 2 }, completion: { result in
				switch result {
				case let .success(value): completions.append(value)
				case let .failure(error): Issue.record("third operation failed: \(error)")
				}
			}
		)
		try await Task.sleep(for: .milliseconds(300))
		let thirdEnteredBeforeSecondRelease = await gate.hasFollowingEntered()
		await gate.releaseHeld()
		let deadline = ContinuousClock.now + .seconds(5)
		while completions.count < 3 && ContinuousClock.now < deadline {
			try await Task.sleep(for: .milliseconds(10))
		}
		#expect(!thirdEnteredBeforeSecondRelease)
		#expect(completions == [0, 1, 2])
		#expect(!processor.hasPendingWork)
	}
}
