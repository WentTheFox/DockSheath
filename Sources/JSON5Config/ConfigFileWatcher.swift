import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Watches a single file for writes/renames/deletes and invokes a callback
/// on the main queue, debounced. Many editors save via delete+recreate, which
/// invalidates the original file descriptor's identity, so on every event this
/// reopens the file by path rather than trusting the existing descriptor.
public final class ConfigFileWatcher {
    private let fileURL: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let queue = DispatchQueue(label: "dev.wentthefox.docksheath.configwatcher")
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval

    public init(fileURL: URL, debounceInterval: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.fileURL = fileURL
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    public func start() {
        queue.async { [weak self] in
            self?.openAndArmSource()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.tearDownSource()
        }
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    private func openAndArmSource() {
        tearDownSource()

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )
        newSource.setEventHandler { [weak self] in
            self?.scheduleNotify()
        }
        newSource.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        newSource.resume()
        source = newSource
    }

    private func tearDownSource() {
        source?.cancel()
        source = nil
    }

    private func scheduleNotify() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reopenAndNotify()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func reopenAndNotify() {
        openAndArmSource()
        DispatchQueue.main.async { [weak self] in
            self?.onChange()
        }
    }
}
