import Foundation
@testable import ClaudeMeter

actor SessionKeyImportServiceStub: SessionKeyImportServiceProtocol {
    let result: Result<ImportedSessionKey, Error>

    init(result: Result<ImportedSessionKey, Error>) {
        self.result = result
    }

    func importSessionKey() async throws -> ImportedSessionKey {
        switch result {
        case .success(let imported):
            return imported
        case .failure(let error):
            throw error
        }
    }
}
