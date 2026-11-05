import Foundation
import Testing
import RangeState

@Suite("Single-phase validation completion", .serialized)
struct ValidationCompletionTests {
    @MainActor
    final class Gate {
        let started = AsyncStream<Void>.makeStream()
        let waiting = AsyncStream<Void>.makeStream()
        var continuation: CheckedContinuation<Void, Never>?
        var released = false
    }

    @MainActor
    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func completionWaitsForInFlightProvider(disjoint: Bool) async throws {
        let gate = Gate()
        let content = UnversionableContent(lengthProvider: { 3 })
        let provider = SinglePhaseRangeValidator<UnversionableContent>.Provider(
            syncValue: { _ in nil },
            mainActorAsyncValue: { range in
                await withCheckedContinuation { continuation in
                    gate.continuation = continuation
                    gate.started.continuation.yield(())
                }
                return .success(range.value)
            }
        )
        let validator = SinglePhaseRangeValidator(configuration: .init(versionedContent: content, provider: provider))
        let target = disjoint ? RangeTarget.set(IndexSet([0, 2])) : .all
        validator.validate(target)
        var started = gate.started.stream.makeAsyncIterator()
        _ = try #require(await started.next())
        let waiter = Task { @MainActor in
            gate.waiting.continuation.yield(())
            await validator.validationCompleted(isolation: MainActor.shared)
            #expect(gate.released, "a dequeued provider still counts as unfinished validation")
        }
        _ = try #require(await gate.waiting.stream.first { @Sendable _ in true })
        if disjoint {
            gate.continuation?.resume()
            _ = try #require(await started.next())
        }
        gate.released = true
        gate.continuation?.resume()
        await waiter.value
    }
}
