import SwiftUI

final class AutoSignal: ObservableObject {
    let interval: DispatchTimeInterval
    
    init(interval: DispatchTimeInterval) {
        self.interval = interval
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: tick)
    }
    
    private func tick() {
        self.objectWillChange.send()
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.tick()
        }
    }
}
