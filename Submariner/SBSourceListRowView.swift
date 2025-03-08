//
//  SBSourceListRowView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-03-06.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

@objc(SBSourceListRowView) class SBSourceListRowView: NSTableRowView {
    // It seems we shouldn't be setting isEmphasized; this provides a grey highlight,
    // consistent with Music/Mail/Finder/etc. We can set this from the selection delegate,
    // but that may result in flashing. The grey highlight also saves us from having to
    // think about recolouring the view item.
    // https://stackoverflow.com/questions/9463871/change-selection-color-on-view-based-nstableview#comment41495226_9594543
    override var isEmphasized: Bool {
        get {
            false
        }
        set {}
    }
}
