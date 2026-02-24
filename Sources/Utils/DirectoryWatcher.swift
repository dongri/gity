//
//  DirectoryWatcher.swift
//  GitY
//
//  FSEvents-based watcher
//

import Combine
import Foundation

class DirectoryWatcher {
    private typealias Callback = (FileSystemEventInfo) -> Void
    private typealias CallbackWrapper = RefCell<Callback>
    
    private var stream: FSEventStreamRef?
    private var processQueue = DispatchQueue(label: "DirectoryWatcherQueue")
    private let subject = PassthroughSubject<FileSystemEventInfo, Never>()
    
    public var publisher: AnyPublisher<FileSystemEventInfo, Never> {
        subject.eraseToAnyPublisher()
    }
    
    deinit {
        stop()
    }
    
    public func start(_ path: String) -> Bool {
        let pathsToWatch = [path] as CFArray
        
        let callback: Callback = { [weak self] in
            if $0.isEmpty { return }
            self?.subject.send($0)
        }
        
        // Use a simple C function pointer approach to avoid memory issues
        let streamContext = UnsafeMutablePointer<FSEventStreamContext>.allocate(capacity: 1)
        streamContext.initialize(to: FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(CallbackWrapper(callback)).toOpaque(),
            retain: nil,
            release: { info in
                guard let info else { return }
                Unmanaged<CallbackWrapper>.fromOpaque(info).release()
            },
            copyDescription: nil
        ))
        
        let eventCallback: FSEventStreamCallback = {
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        in
            guard let clientCallBackInfo else {
                return
            }
            let wrapper = Unmanaged<CallbackWrapper>
                .fromOpaque(clientCallBackInfo)
                .takeUnretainedValue()
            // TODO: in the future you can expand FileSystemEventInfo with extra fields
            let pathList = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            
            let payload = FileSystemEventInfo(
                pathList: pathList
            )
            wrapper.value(payload)
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
        
        guard let stream else {
            return false
        }
        
        FSEventStreamSetDispatchQueue(stream, processQueue)
        FSEventStreamStart(stream)
        return true
    }
    
    private func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

struct FileSystemEventInfo {
    let pathList: [String]
    
    var isEmpty: Bool {
        pathList.isEmpty
    }
}
