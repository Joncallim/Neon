import Foundation

import Rearrange

public final class SinglePhaseRangeValidator<Content: VersionedContent> {
	public typealias ContentRange = RangeValidator<Content>.ContentRange
	public typealias Provider = HybridSyncAsyncValueProvider<ContentRange, Validation, Never>

	private struct ValidationOperation {
		let contentRange: ContentRange
		let target: RangeTarget
	}

	public struct Configuration {
		public let versionedContent: Content
		public let provider: Provider

		public init(
			versionedContent: Content,
			provider: Provider
		) {
			self.versionedContent = versionedContent
			self.provider = provider
		}
	}

	private let primaryValidator: RangeValidator<Content>
	private var eventQueue: AwaitableQueue<ValidationOperation>
	private var completionWaiters: [CheckedContinuation<Void, Never>] = []
	private var scheduledValidations = 0

	public let configuration: Configuration
	public var validationHandler: (NSRange, Bool) -> Void = { _, _ in }
	public var name: String?

	public init(configuration: Configuration) {
		self.configuration = configuration
		self.primaryValidator = RangeValidator<Content>(content: configuration.versionedContent)
		self.eventQueue = AwaitableQueue()
	}

	private var version: Content.Version {
		configuration.versionedContent.currentVersion
	}

	package func isValid(_ target: RangeTarget) -> Bool {
		primaryValidator.isValid(target)
	}

	/// Manually mark a region as invalid.
	public func invalidate(_ target: RangeTarget) {
		primaryValidator.invalidate(target)
	}

	@discardableResult
	public func validate(
		_ target: RangeTarget,
		isolation: isolated (any Actor)
	) -> RangeValidator<Content>.Action {
		// capture this first, because we're about to start one
		let outstanding = primaryValidator.hasOutstandingValidations

		let action = primaryValidator.beginValidation(of: target)

		switch action {
		case .none:
			eventQueue.handlePendingWaiters()
			resumeCompletionWaitersIfIdle()
			return .none
		case let .needed(contentRange):
			let operation = ValidationOperation(contentRange: contentRange, target: target)

			// if we have an outstanding async operation going, force this to be async too
			if outstanding {
				enqueueValidation(operation, isolation: isolation)
				return action
			}

			guard let validation = configuration.provider.sync(contentRange) else {
				enqueueValidation(operation, isolation: isolation)
				return action
			}

			completePrimaryValidation(of: operation, with: validation, isolation: isolation)

			return .none
		}
	}

	@MainActor
	@preconcurrency
	@discardableResult
	public func validate(
		_ target: RangeTarget
	) -> RangeValidator<Content>.Action {
		validate(target, isolation: MainActor.shared)
	}

	private func completePrimaryValidation(of operation: ValidationOperation, with validation: Validation, isolation: isolated (any Actor)) {
		primaryValidator.completeValidation(of: operation.contentRange, with: validation)
		defer { resumeCompletionWaitersIfIdle() }

		switch validation {
		case .stale:
			scheduledValidations += 1
			Task<Void, Never> {
				defer {
					scheduledValidations -= 1
					resumeCompletionWaitersIfIdle()
				}
				if operation.contentRange.version == self.version {
					print("version unchanged after stale results, stopping validation")
					return
				}

				validate(operation.target, isolation: isolation)
			}
		case let .success(range):
			let complete = primaryValidator.isValid(operation.target)

			validationHandler(range, complete)

			// this only makes sense if the content has remained unchanged
			if complete {
				eventQueue.handlePendingWaiters()
				return
			}

			scheduledValidations += 1
			Task<Void, Never> {
				defer {
					scheduledValidations -= 1
					resumeCompletionWaitersIfIdle()
				}
				validate(operation.target, isolation: isolation)
			}
		}
	}

	/// Update internal state in response to a mutation.
	///
	/// This method must be invoked on every content change. The `range` parameter must refer to the range that **was** changed. Consider the example text `"abc"`.
	///
	/// Inserting a "d" at the end:
	///
	///     range = NSRange(3..<3)
	///     delta = 1
	///
	/// Deleting the middle "b":
	///
	///     range = NSRange(1..<2)
	///     delta = -1
	public func contentChanged(in range: NSRange, delta: Int) {
		primaryValidator.contentChanged(in: range, delta: delta)
	}

	private func enqueueValidation(_ operation: ValidationOperation, isolation: isolated any Actor) {
		eventQueue.enqueue(operation)

		Task<Void, Never> {
			await self.validateRangeAsync(isolation: isolation)
		}
	}

	private func validateRangeAsync(isolation: isolated any Actor) async {
		guard let operation = eventQueue.next() else {
			preconditionFailure("There must always be a next operation to process")
		}

		let validation = await self.configuration.provider.async(isolation: isolation, operation.contentRange)

		completePrimaryValidation(of: operation, with: validation, isolation: isolation)
	}

	private var hasPendingValidation: Bool {
		primaryValidator.hasOutstandingValidations || scheduledValidations > 0
	}

	private func resumeCompletionWaitersIfIdle() {
		guard !hasPendingValidation else { return }
		let waiters = completionWaiters
		completionWaiters.removeAll()
		for waiter in waiters { waiter.resume() }
	}

	public func validationCompleted(isolation: isolated any Actor) async {
		guard hasPendingValidation else { return }
		// A provider is removed from eventQueue when it starts. It remains
		// outstanding until its result and any follow-up regions are processed.
		await withCheckedContinuation { completionWaiters.append($0) }
	}
}
