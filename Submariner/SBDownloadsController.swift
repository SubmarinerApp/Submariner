//
//  SBDownloadsController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-19.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import SwiftUI

@objc class SBDownloadsController: SBViewController, ObservableObject {
    @Published var downloadActivities: [SBOperationActivity] = []
    
    // it's ok to use nil if we aren't rehydrating a nib, SBViewController doesn't mind?
    override class func nibName() -> String! {
        nil
    }
    
    override func loadView() {
        title = "Downloads"
        view = NSHostingView(rootView: DownloadsContentView(downloadsController: self))
    }
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SBDownloadsController.subsonicDownloadStarted(notification:)),
                                               name: SBSubsonicDownloadOperation.DownloadStartedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SBDownloadsController.subsonicDownloadFinished(notification:)),
                                               name: SBSubsonicDownloadOperation.DownloadFinishedNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: SBSubsonicDownloadOperation.DownloadStartedNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: SBSubsonicDownloadOperation.DownloadFinishedNotification, object: nil)
    }
    
    @objc var itemCount: Int {
        return downloadActivities.count
    }
    
    @objc func subsonicDownloadStarted(notification: NSNotification) {
        if let item = notification.object as? SBOperationActivity {
            downloadActivities.append(item)
        }
    }
    
    @objc func subsonicDownloadFinished(notification: NSNotification) {
        if let item = notification.object as? SBOperationActivity {
            downloadActivities.removeAll { itemInArray in itemInArray.id == item.id }
        }
    }
    
    struct DownloadItemView: View {
        @ObservedObject var item: SBOperationActivity
        
        var body: some View {
            VStack(alignment: .leading) {
                switch (item.progress) {
                //case .none:
                //    Text(item.operationName)
                case .indeterminate, .none:
                    ProgressView(item.operationName)
                        .progressViewStyle(.linear)
                case .determinate(let n, let outOf):
                    ProgressView(item.operationName, value: n, total: outOf)
                        .progressViewStyle(.linear)
                }
                Text(item.operationInfo)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct DownloadsContentView: View {
        @ObservedObject var downloadsController: SBDownloadsController
        
        var body: some View {
            // TODO: It would be nice if this was seamless to the toolbar like NSCollectionView was.
            // TODO: Consistent row height.
            List(downloadsController.downloadActivities) {
                DownloadItemView(item: $0)
            }
            .modify {
                if #available(macOS 12, *) {
                    $0.listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
        }
    }
}
