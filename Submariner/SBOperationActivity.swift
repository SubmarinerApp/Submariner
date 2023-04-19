//
//  SBOperationActivity.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

class SBOperationActivity: ObservableObject, Identifiable, Equatable {
    static func == (lhs: SBOperationActivity, rhs: SBOperationActivity) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let operationName: String
    @Published var operationInfo: String = ""
    @Published var progress: Progress = .none
    
    init(name: String) {
        operationName = name
    }
    
    enum Progress {
        case none
        case indeterminate(n: Float)
        case determinate(n: Float, outOf: Float)
    }
}
