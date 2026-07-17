import Foundation

extension NoteStore {
    @discardableResult
    func createCodeEnvironment(name: String = "Untitled Environment", activationCommand: String = "") -> CodeEnvironment {
        let environment = CodeEnvironment(name: name, activationCommand: activationCommand)
        codeEnvironments.append(environment)
        save()
        return environment
    }

    func updateCodeEnvironment(_ environment: CodeEnvironment) {
        guard let idx = codeEnvironments.firstIndex(where: { $0.id == environment.id }) else { return }
        codeEnvironments[idx] = environment
        save()
    }

    func deleteCodeEnvironment(_ environment: CodeEnvironment) {
        codeEnvironments.removeAll { $0.id == environment.id }
        save()
    }
}
