//
//  RefCell.swift
//  GitY
//
//  Created by Sergey on 24.02.2026.
//

class RefCell<T> {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
}
