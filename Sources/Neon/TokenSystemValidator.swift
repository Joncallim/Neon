import Foundation

import RangeState

@MainActor
final class TokenSystemValidator<Interface: TextSystemInterface> {
	typealias Validator = RangeValidator<Interface.Content>

	private let textSystem: Interface
	private let tokenProvider: TokenProvider
	private var isActive = true

	init(textSystem: Interface, tokenProvider: TokenProvider) {
		self.textSystem = textSystem
		self.tokenProvider = tokenProvider
	}

	func deactivate() {
		isActive = false
	}

	var validationProvider: HybridSyncAsyncValueProvider<Validator.ContentRange, Validation, Never> {
		.init(
			syncValue: { self.validate($0) },
			asyncValue: { [self] _, range in await self.validate(range) }
		)
	}

	private var currentVersion: Interface.Content.Version {
		textSystem.content.currentVersion
	}

	private func validate(_ range: Validator.ContentRange) -> Validation? {
		guard isActive, range.version == currentVersion else { return .stale }

		guard let application = tokenProvider.sync(range.value) else {
			return nil
		}

		// A provider can suspend or synchronously reenter editing. Its result
		// retains the request's version, not the current document's authority.
		guard isActive, range.version == currentVersion else { return .stale }

		applyStyles(for: application)

		return .success(range.value)
	}

	private func validate(_ range: Validator.ContentRange) async -> Validation {
		guard isActive, range.version == currentVersion else { return .stale }

		// https://github.com/apple/swift/pull/71143
		let application = await tokenProvider.async(isolation: MainActor.shared, range.value)

		// A provider can suspend or synchronously reenter editing. Its result
		// retains the request's version, not the current document's authority.
		guard isActive, range.version == currentVersion else { return .stale }

		applyStyles(for: application)

		return .success(range.value)
	}

	private func applyStyles(for application: TokenApplication) {
		textSystem.applyStyles(for: application)
	}
}
