//
//  SBMessageTextView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-04-08.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import SwiftUI

struct SBMessageTextView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SBMessageTextView(message: "Hello world")
}
