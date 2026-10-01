import Foundation
import Darwin

// Runs in the simulator, not macOS, so its FileCoordinator talks to the same
// provider as Files. It only creates external fixtures; it never imports them.
let arguments = CommandLine.arguments
guard arguments.count == 4 else { fatalError("Expected source, fixture folder, filename") }
let source = URL(fileURLWithPath: arguments[1])
let folder = URL(fileURLWithPath: arguments[2], isDirectory: true)
let name = arguments[3]
guard folder.lastPathComponent == "Tayya-test-files",
      ["Picker-fixture.pdf", "Picker-office.pptx"].contains(name) else {
    fatalError("Only the dedicated external fixture directory may be written")
}
do {
    let bytes = try Data(contentsOf: source)
    let destination = folder.appendingPathComponent(name)
    var coordinationError: NSError?
    var writingError: Error?
    let coordinator = NSFileCoordinator(filePresenter: nil)
    coordinator.coordinate(writingItemAt: destination, options: [], error: &coordinationError) { url in
        do { try bytes.write(to: url) } catch { writingError = error }
    }
    if let error = coordinationError { throw error }
    if let error = writingError { throw error }
    var readingError: Error?
    coordinator.coordinate(readingItemAt: destination, options: [], error: &coordinationError) { url in
        do {
            guard try Data(contentsOf: url) == bytes else {
                throw NSError(domain: "TayyaFixtures", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Coordinated fixture bytes differ"])
            }
        } catch { readingError = error }
    }
    if let error = coordinationError { throw error }
    if let error = readingError { throw error }
    print("Simulator-coordinated external fixture ready: \(name)")
} catch {
    fputs("External fixture preparation failed: \(error)\n", stderr)
    exit(1)
}
