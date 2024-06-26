//
//  SBSubsonicDownloadOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-18.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBSubsonicDownloadOperation")

@objc class SBSubsonicDownloadOperation: SBOperation, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    private let track: SBTrack
    
    @objc init!(managedObjectContext mainContext: NSManagedObjectContext!, trackID: NSManagedObjectID) {
        // Reconstitute the track because Core Data objects can't cross thread boundaries.
        track = mainContext.object(with: trackID) as! SBTrack
        
        let activityName = String.init(format: "Downloading %@%@%@",
                                       Locale.current.quotationBeginDelimiter ?? "\"",
                                       track.itemName!,
                                       Locale.current.quotationEndDelimiter ?? "\"")
        
        super.init(managedObjectContext: mainContext, name: activityName)
        self.operationInfo = "Pending Request..."
        self.progress = .none
    }
    
    override func main() {
        if track.localTrack != nil {
            // We don't need to redownload the track.
            self.finish()
            return
        }
        autoreleasepool {
            // We don't need to do any transformation here,
            // as downloadURL will get the auth params from SBServer.
            let url = track.downloadURL()!
            logger.info("Downloading track at URL: \(url)")
            let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: request)
            task.resume()
        }
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Auth)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if (challenge.previousFailureCount == 0) {
            if let server = track.server, let username = server.username, let password = server.password {
                let credential = URLCredential(user: username,
                                               password: password,
                                               persistence: .none)
                
                completionHandler(.useCredential, credential)
            }
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (State)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Failure downloading track with URLSession, error \(error, privacy: .public)")
            DispatchQueue.main.async {
                NSApp.presentError(error)
            }
            self.finish()
            session.invalidateAndCancel()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Success
        DispatchQueue.main.async {
            self.operationInfo = "Importing track..."
        }
        
        // SBImportOperation needs an audio file extension. Rename the file.
        var proposedMimeType = downloadTask.response?.mimeType
        if proposedMimeType == "application/x-download" {
            // XXX: get a better one
            proposedMimeType = nil
        }
        let fileType = UTType(mimeType: proposedMimeType ?? "audio/mp3") ?? UTType.mp3
        let temporaryFile = URL.temporaryFile().appendingPathExtension(for: fileType)
        try! FileManager.default.moveItem(at: location, to: temporaryFile)
        
        // Now import.
        if let importOperation = SBImportOperation(managedObjectContext: mainContext, file: temporaryFile, remoteTrackID: track.objectID) {
            OperationQueue.sharedDownloadQueue.addOperation(importOperation)
        }
        
        self.finish()
        session.finishTasksAndInvalidate()
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Progress)
    
    private let byteCountFormatter = MeasurementFormatter()
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let totalWritten = Measurement<UnitInformationStorage>(value: Double(totalBytesWritten), unit: .bytes).converted(to: .megabytes)
        
        if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
            let totalToWrite = Measurement<UnitInformationStorage>(value: Double(totalBytesExpectedToWrite), unit: .bytes)
                .converted(to: .megabytes)
            DispatchQueue.main.async {
                self.progress = .determinate(n: Float(totalBytesWritten), outOf: Float(totalBytesExpectedToWrite))
                self.operationInfo = String.init(format: "Downloaded %@/%@",
                                                          self.byteCountFormatter.string(from: totalWritten),
                                                          self.byteCountFormatter.string(from: totalToWrite))
            }
        } else {
            DispatchQueue.main.async {
                self.progress = .indeterminate(n: Float(totalBytesWritten))
                self.operationInfo = String.init(format: "Downloaded %@",
                                                          self.byteCountFormatter.string(from: totalWritten))
            }
        }
    }
}
