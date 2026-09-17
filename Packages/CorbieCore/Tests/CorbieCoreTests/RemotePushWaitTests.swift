import Foundation
import Testing
@testable import CorbieCore

@Suite struct InFlightTasksTests {
    @Test func waitingReturnsOnlyAfterEveryStartedTaskHasFinished() async {
        let tasks = InFlightTasks()
        let finished = ReloadCounter()
        for delay in [30, 60] {
            tasks.run {
                try? await Task.sleep(for: .milliseconds(delay))
                finished.increment()
            }
        }
        await tasks.waitUntilEmpty()
        #expect(finished.count == 2)
        #expect(tasks.count == 0)
    }

    @Test func aTaskStartedByAnotherTaskIsWaitedForToo() async {
        let tasks = InFlightTasks()
        let finished = ReloadCounter()
        tasks.run {
            try? await Task.sleep(for: .milliseconds(20))
            tasks.run {
                try? await Task.sleep(for: .milliseconds(40))
                finished.increment()
            }
        }
        await tasks.waitUntilEmpty()
        #expect(finished.count == 1)
    }

    @Test func waitingWithNothingStartedReturnsAtOnce() async {
        let tasks = InFlightTasks()
        let started = ContinuousClock.now
        await tasks.waitUntilEmpty()
        #expect(ContinuousClock.now - started < .milliseconds(50))
    }
}

@Suite struct DeadlineTests {
    @Test func aQuickOperationHandsBackItsValue() async {
        let value = await Deadline.run(within: .seconds(5)) { 42 }
        #expect(value == 42)
    }

    @Test func aSlowOperationIsAbandonedAtTheLimit() async {
        let started = ContinuousClock.now
        let value = await Deadline.run(within: .milliseconds(50)) { () async -> Int in
            try? await Task.sleep(for: .seconds(3))
            return 7
        }
        #expect(value == nil)
        #expect(ContinuousClock.now - started < .seconds(2))
    }
}
