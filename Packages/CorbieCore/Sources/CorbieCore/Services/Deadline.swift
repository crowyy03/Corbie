import Foundation

public enum Deadline {
    public static func run<Value: Sendable>(
        within limit: Duration,
        _ operation: @escaping @Sendable () async -> Value
    ) async -> Value? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Value?, Never>) in
            let first = FirstAnswer(continuation)
            let timer = Task {
                guard (try? await Task.sleep(for: limit)) != nil else { return }
                first.resume(with: nil)
            }
            Task {
                let value = await operation()
                timer.cancel()
                first.resume(with: value)
            }
        }
    }
}

private final class FirstAnswer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value?, Never>?

    init(_ continuation: CheckedContinuation<Value?, Never>) {
        self.continuation = continuation
    }

    func resume(with value: Value?) {
        let waiting: CheckedContinuation<Value?, Never>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume(returning: value)
    }
}
