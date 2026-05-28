import Foundation

/// Watches a single file path for external modification, deletion, or
/// atomic replacement (the temp-file-and-rename dance used by TextEdit
/// and most other macOS editors).
///
/// The `onChange` closure is invoked on the main queue after a short
/// debounce. The watcher automatically re-attaches to the file at the
/// same `URL` after destructive events so it keeps working across
/// atomic saves — without that, a single external save would silently
/// orphan the watcher.
final class FileChangeWatcher {

    private(set) var url: URL?
    private let onChange: () -> Void
    private let debounce: TimeInterval

    private var source: DispatchSourceFileSystemObject?
    private var coalesceItem: DispatchWorkItem?

    init(debounce: TimeInterval = 0.15, onChange: @escaping () -> Void) {
        self.debounce = debounce
        self.onChange = onChange
    }

    deinit { stop() }

    /// Begin watching `url`. Any previous watch is cancelled first.
    func start(url: URL) {
        stop()
        self.url = url

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .delete, .rename, .revoke],
            queue: .main
        )

        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let events = src.data
            let destructive = events.contains(.delete)
                || events.contains(.rename)
                || events.contains(.revoke)

            self.coalesceItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.onChange()
                // After atomic save/rename the old fd is detached from
                // the file in the directory; re-open at the same path
                // to keep watching the new inode.
                if destructive, let url = self.url {
                    self.start(url: url)
                }
            }
            self.coalesceItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounce, execute: item)
        }

        src.setCancelHandler {
            close(fd)
        }

        source = src
        src.resume()
    }

    /// Stop watching and release the file descriptor.
    func stop() {
        coalesceItem?.cancel()
        coalesceItem = nil
        source?.cancel()
        source = nil
    }
}
