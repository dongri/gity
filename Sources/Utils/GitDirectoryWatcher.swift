//
//  GitDirectoryWatcher.swift
//  GitY
//
//  FSEvents-based watcher for .git directory changes (more reliable than DispatchSource)
//

import Foundation
import Combine

class GitDirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void
    private let path: String
    
    init?(gitDirectory: URL, callback: @escaping () -> Void) {
        self.path = gitDirectory.path
        self.callback = callback
        
        guard startWatching() else {
            return nil
        }
    }
    
    deinit {
        stop()
    }
    
    private func startWatching() -> Bool {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let paths = [path] as CFArray
        
        let eventCallback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let watcher = Unmanaged<GitDirectoryWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            // Check if any event relates to HEAD file
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            for i in 0..<numEvents {
                let path = paths[i]
                // Trigger callback for HEAD file changes or refs changes
                if path.contains("HEAD") || path.contains("refs/heads") {
                    DispatchQueue.main.async {
                        watcher.callback()
                    }
                    break
                }
            }
        }
        
        stream = FSEventStreamCreate(
            nil,
            eventCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // Latency in seconds (acts as debounce)
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        
        guard let stream = stream else {
            return false
        }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        
        return true
    }
    
    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
