//
//  GitDirectoryWatcher.swift
//  GitY
//
//  FSEvents-based watcher for .git directory changes (more reliable than DispatchSource)
//

import Foundation

class GitDirectoryWatcher {
    private var stream: FSEventStreamRef?
    private var callback: (() -> Void)?
    private let path: String
    private var isRunning = false
    
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
        let pathsToWatch = [path] as CFArray
        
        // Use a simple C function pointer approach to avoid memory issues
        let streamContext = UnsafeMutablePointer<FSEventStreamContext>.allocate(capacity: 1)
        streamContext.initialize(to: FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(CallbackWrapper(callback: callback)).toOpaque(),
            retain: nil,
            release: { info in
                guard let info = info else { return }
                Unmanaged<CallbackWrapper>.fromOpaque(info).release()
            },
            copyDescription: nil
        ))
        
        let eventCallback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            // Check if any event relates to HEAD file or refs
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            
            for path in paths {
                // Trigger callback for HEAD file changes or refs changes
                if path.contains("HEAD") || path.contains("refs/heads") || path.contains("refs/tags") {
                    DispatchQueue.main.async {
                        wrapper.callback?()
                    }
                    break
                }
            }
        }
        
        stream = FSEventStreamCreate(
            nil,
            eventCallback,
            streamContext,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // Latency in seconds (acts as debounce)
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        
        streamContext.deallocate()
        
        guard let stream = stream else {
            return false
        }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        isRunning = true
        
        return true
    }
    
    func stop() {
        guard isRunning, let stream = stream else { return }
        isRunning = false
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        self.callback = nil
    }
}

// Helper class to wrap the callback for proper memory management
private class CallbackWrapper {
    var callback: (() -> Void)?
    
    init(callback: (() -> Void)?) {
        self.callback = callback
    }
}
