//
//  View+Modify.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-19.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation
import SwiftUI

// https://blog.overdesigned.net/posts/2020-09-23-swiftui-availability/
extension View {
    func modify<T: View>(@ViewBuilder _ modifier: (Self) -> T) -> some View {
        return modifier(self)
    }
}
