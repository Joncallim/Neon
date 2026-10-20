import Foundation
import SwiftTreeSitter
import Testing
import TreeSitterClient
@testable import Neon

private enum PendingQuery: Error {
	case unavailable
}

struct SyncQueryFallbackTests {
	@MainActor
	@Test func synchronousQueryErrorLeavesRangeForAsyncStyling() async {
		let requested = NSRange(location: 15, length: 6)
		var syncRanges: [IndexSet] = []
		var asyncRanges: [IndexSet] = []
		let highlights = TreeSitterClient.HighlightsProvider(
			syncValue: { params in
				syncRanges.append(params.indexSet)
				throw PendingQuery.unavailable
			},
			mainActorAsyncValue: { params in
				asyncRanges.append(params.indexSet)
				return [NamedRange(
					name: "markup.raw",
					range: requested,
					pointRange: Point(row: 0, column: 15)..<Point(row: 0, column: 21)
				)]
			}
		)
		let provider = TreeSitterClient.makeTokenProvider(
			highlightsProvider: highlights, textProvider: { _, _ in nil }
		)

		#expect(provider.sync(requested) == nil)
		let application = await provider.async(isolation: MainActor.shared, requested)
		#expect(syncRanges == [IndexSet(integersIn: requested)])
		#expect(asyncRanges == [IndexSet(integersIn: requested)])
		#expect(application.action == .replace)
		#expect(application.range == requested)
		#expect(application.tokens == [Token(name: "markup.raw", range: requested)])
	}
}
