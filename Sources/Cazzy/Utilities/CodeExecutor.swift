import Foundation

/// Thread-safe accumulator for a pipe's output, drained continuously via a
/// `readabilityHandler` rather than read in one shot at termination — a script that prints
/// more than the ~64KB pipe buffer before exiting would otherwise block on write() forever
/// and the process would never terminate (a well-known Process+Pipe deadlock).
private final class PipeCollector {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Ensures a continuation is resumed exactly once even though the failure path, the
/// termination handler, and (indirectly, via process.terminate()) the timeout can all race.
private final class ResumeGuard {
    private var resumed = false
    private let lock = NSLock()

    /// Runs `body` only on the first call; subsequent calls are no-ops.
    func resumeOnce(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        body()
    }
}

/// Runs a note's ```exec code blocks via the user's login shell (so PATH includes
/// conda/pyenv/homebrew, matching what they'd get running the same script in Terminal).
/// This is the app's only use of `Process()` — deliberately explicit-click-only, executing
/// the user's own scripts on their own machine under their own account, the same trust
/// boundary as opening Terminal. Never triggered automatically.
enum CodeExecutor {
    /// Backstop only — an orphaned process could otherwise run forever if the note is
    /// closed mid-run. The primary control is the Cancel button in `CodeRunner`.
    private static let safetyTimeout: TimeInterval = 600

    static func run(
        language: ExecutionLanguage,
        code: String,
        onLaunch: @escaping (Process) -> Void
    ) async -> (stdout: String, stderr: String, exitCode: Int32, duration: Double) {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(language.fileExtension)

        do {
            try code.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            return ("", "Failed to write script: \(error.localizedDescription)", 1, 0)
        }
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let command = "\(language.interpreterCommand) \(shellQuote(scriptURL.path))"
        return await runLoginShell(command, onLaunch: onLaunch, timeout: safetyTimeout)
    }

    /// Captures interpreter version + a best-effort installed-package list.
    static func captureEnvironment(language: ExecutionLanguage) async -> EnvironmentSnapshot {
        let versionResult = await runLoginShell(
            "\(language.interpreterCommand) --version",
            onLaunch: { _ in },
            timeout: 15
        )
        let version = [versionResult.stdout, versionResult.stderr]
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let packageCommand: String?
        switch language {
        case .python: packageCommand = "python3 -m pip list --format=freeze 2>/dev/null"
        case .r: packageCommand = #"Rscript -e 'cat(rownames(installed.packages()), sep="\n")' 2>/dev/null"#
        case .bash: packageCommand = nil
        }

        var packages = ""
        if let packageCommand {
            let result = await runLoginShell(packageCommand, onLaunch: { _ in }, timeout: 20)
            packages = String(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        }

        return EnvironmentSnapshot(interpreterVersion: version, packageList: packages)
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runLoginShell(
        _ command: String,
        onLaunch: @escaping (Process) -> Void,
        timeout: TimeInterval
    ) async -> (stdout: String, stderr: String, exitCode: Int32, duration: Double) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutCollector = PipeCollector()
            let stderrCollector = PipeCollector()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                stdoutCollector.append(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                stderrCollector.append(handle.availableData)
            }

            let start = Date()
            let resumeGuard = ResumeGuard()

            process.terminationHandler = { proc in
                resumeGuard.resumeOnce {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    let duration = Date().timeIntervalSince(start)
                    continuation.resume(returning: (stdoutCollector.string, stderrCollector.string, proc.terminationStatus, duration))
                }
            }

            do {
                try process.run()
                onLaunch(process)
            } catch {
                resumeGuard.resumeOnce {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: ("", "Failed to launch: \(error.localizedDescription)", 1, 0))
                }
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }
}

/// Owns one in-flight code-block run so a view can show a spinner and offer Cancel.
@MainActor
final class CodeRunner: ObservableObject {
    @Published private(set) var isRunning = false
    private weak var activeProcess: Process?

    func run(language: ExecutionLanguage, code: String) async -> (stdout: String, stderr: String, exitCode: Int32, duration: Double) {
        isRunning = true
        let result = await CodeExecutor.run(language: language, code: code) { [weak self] process in
            Task { @MainActor in self?.activeProcess = process }
        }
        activeProcess = nil
        isRunning = false
        return result
    }

    func cancel() {
        activeProcess?.terminate()
    }
}
