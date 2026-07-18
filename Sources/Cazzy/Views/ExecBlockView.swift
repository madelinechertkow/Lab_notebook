import SwiftUI

/// Renders one ```exec code block in note preview: the code itself, a Run/Cancel control,
/// and (once run) stdout/stderr, exit status, and the captured environment snapshot.
struct ExecBlockView: View {
    @EnvironmentObject var theme: ThemeStore
    let blockID: String
    let code: String
    let language: ExecutionLanguage?
    var activationCommand: String? = nil
    let result: CodeBlockResult?
    let onResult: (CodeBlockResult) -> Void
    var onCodeChange: (String) -> Void = { _ in }

    @StateObject private var runner = CodeRunner()
    @State private var environmentExpanded = false
    @State private var editedCode: String

    init(
        blockID: String,
        code: String,
        language: ExecutionLanguage?,
        activationCommand: String? = nil,
        result: CodeBlockResult?,
        onResult: @escaping (CodeBlockResult) -> Void,
        onCodeChange: @escaping (String) -> Void = { _ in }
    ) {
        self.blockID = blockID
        self.code = code
        self.language = language
        self.activationCommand = activationCommand
        self.result = result
        self.onResult = onResult
        self.onCodeChange = onCodeChange
        self._editedCode = State(initialValue: code)
    }

    private var isStale: Bool {
        guard let result else { return false }
        return result.codeSnapshot != editedCode
    }

    private var exitSucceeded: Bool {
        result?.exitCode == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            TextEditor(text: $editedCode)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 60)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .onChange(of: editedCode) { onCodeChange($0) }
                .onChange(of: code) { if $0 != editedCode { editedCode = $0 } }

            if let result {
                Divider().overlay(theme.divider)
                outputSection(result)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.divider, lineWidth: 1))
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: language?.symbol ?? "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 11))
            Text(language?.displayName ?? "No language set")
                .font(theme.bodyFont(11, weight: .semibold))

            if isStale {
                Label("Changed since last run", systemImage: "exclamationmark.circle")
                    .font(theme.bodyFont(10, weight: .medium))
                    .foregroundStyle(.orange)
            }

            Spacer()

            runControl
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var runControl: some View {
        if runner.isRunning {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Button("Cancel") { runner.cancel() }
                    .buttonStyle(.plain)
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(.red)
            }
        } else if let language {
            Button {
                runBlock(language: language)
            } label: {
                Label(result == nil ? "Run" : "Run again", systemImage: "play.fill")
                    .font(theme.bodyFont(11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
        } else {
            Text("Set a language above to run")
                .font(theme.bodyFont(10))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func outputSection(_ result: CodeBlockResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: exitSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(exitSucceeded ? Color.green : Color.red)
                Text(exitSucceeded ? "Exit 0" : "Exit \(result.exitCode)")
                    .font(theme.bodyFont(11, weight: .medium))
                Text(result.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                Text(String(format: "%.2fs", result.durationSeconds))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
            }

            if !result.stdout.isEmpty {
                Text(result.stdout)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !result.stderr.isEmpty {
                Text(result.stderr)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            environmentDisclosure(result.environment)
        }
        .padding(12)
    }

    private func environmentDisclosure(_ environment: EnvironmentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                environmentExpanded.toggle()
            } label: {
                Label("Environment", systemImage: environmentExpanded ? "chevron.down" : "chevron.right")
                    .font(theme.bodyFont(10, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)

            if environmentExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !environment.interpreterVersion.isEmpty {
                        Text(environment.interpreterVersion)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    if !environment.packageList.isEmpty {
                        ScrollView {
                            Text(environment.packageList)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .scrollContentBackground(.hidden)
                        .frame(maxHeight: 160)
                    }
                }
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.editorBackground))
            }
        }
    }

    private func runBlock(language: ExecutionLanguage) {
        let startedAt = Date()
        let runCode = editedCode
        Task {
            async let executionResult = runner.run(language: language, code: runCode, activationCommand: activationCommand)
            async let environment = CodeExecutor.captureEnvironment(language: language, activationCommand: activationCommand)
            let (execOutcome, env) = await (executionResult, environment)
            let result = CodeBlockResult(
                id: blockID,
                codeSnapshot: runCode,
                stdout: execOutcome.stdout,
                stderr: execOutcome.stderr,
                exitCode: execOutcome.exitCode,
                startedAt: startedAt,
                durationSeconds: execOutcome.duration,
                environment: env
            )
            onResult(result)
        }
    }
}
