//
//  DirectoryWatcher.swift
//  GitY
//
//  Directory watcher utility for file system changes
//

import Foundation

class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let fd: Int32
    private let callback: () -> Void
    
    init?(url: URL, callback: @escaping () -> Void) {
        self.callback = callback
        
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            self?.callback()
        }
        
        source.setCancelHandler { [fd] in
            close(fd)
        }
        
        source.resume()
        self.source = source
    }
    
    deinit {
        stop()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
}
