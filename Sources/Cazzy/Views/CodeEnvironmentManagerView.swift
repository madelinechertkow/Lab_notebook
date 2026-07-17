import SwiftUI

struct CodeEnvironmentManagerView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: NoteStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingEnvironment: CodeEnvironment?
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Code Environments")
                    .font(theme.displayFont(16))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("Add Environment") {
                    editingEnvironment = CodeEnvironment(name: "", activationCommand: "")
                    showingEditor = true
                }
            }
            .padding([.horizontal, .top], 20)

            Text("Each is a shell command run before a code block's interpreter — e.g. \"conda activate ds\" or \"source ~/venvs/myenv/bin/activate\" — so scripts execute inside a specific environment instead of your default login shell.")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)

            if store.codeEnvironments.isEmpty {
                Spacer()
                Text("No environments yet")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach(store.codeEnvironments) { environment in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(environment.name.isEmpty ? "Untitled Environment" : environment.name)
                                    .font(theme.bodyFont(13, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                Text(environment.activationCommand.isEmpty ? "No activation command" : environment.activationCommand)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                editingEnvironment = environment
                                showingEditor = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.textSecondary)

                            Button(role: .destructive) {
                                store.deleteCodeEnvironment(environment)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }

            Divider().overlay(theme.divider)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 460, height: 420)
        .background(theme.background)
        .sheet(isPresented: $showingEditor) {
            if let editingEnvironment {
                CodeEnvironmentEditorSheet(environment: editingEnvironment) { updated in
                    if store.codeEnvironments.contains(where: { $0.id == updated.id }) {
                        store.updateCodeEnvironment(updated)
                    } else {
                        store.createCodeEnvironment(name: updated.name, activationCommand: updated.activationCommand)
                    }
                }
            }
        }
    }
}

private struct CodeEnvironmentEditorSheet: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var activationCommand: String
    let environmentID: UUID
    var onSave: (CodeEnvironment) -> Void

    init(environment: CodeEnvironment, onSave: @escaping (CodeEnvironment) -> Void) {
        self._name = State(initialValue: environment.name)
        self._activationCommand = State(initialValue: environment.activationCommand)
        self.environmentID = environment.id
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Code Environment")
                .font(theme.displayFont(15))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 5) {
                Text("Name").font(theme.bodyFont(11)).foregroundStyle(theme.textSecondary)
                TextField("e.g. Data Science (conda)", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Activation command").font(theme.bodyFont(11)).foregroundStyle(theme.textSecondary)
                TextField("e.g. conda activate ds", text: $activationCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(CodeEnvironment(id: environmentID, name: name, activationCommand: activationCommand))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(theme.background)
    }
}
