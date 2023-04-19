//
//  SBSubsonicDownloadOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-18.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

@objc class SBSubsonicDownloadOperation: SBOperation, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    // ugh, forced to make this nullable var instead of leteven if it can't be because of swift ctor order rules
    private var libraryID: SBLibraryID?
    
    @objc var trackID: SBTrackID?
    @objc let activity = SBOperationActivity()
    
    override init!(managedObjectContext mainContext: NSManagedObjectContext!) {
        super.init(managedObjectContext: mainContext)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SBSubsonicDownloadStarted"), object: activity)
        // get the handle to the library ID
        let libraryRequest = NSFetchRequest<SBLibrary>(entityName: "Library")
        let library = try! mainContext.fetch(libraryRequest).first
        libraryID = library!.objectID()
    }
    
    override func main() {
        autoreleasepool {
            let track = self.threadedContext.object(with: trackID!) as! SBTrack
            
            activity.operationName = String.init(format: "Downloading \"%@\"", track.itemName)
            activity.operationInfo = "Pending Request..."
            activity.indeterminated = true
            
            // We don't need to do any transformation here,
            // as downloadURL will get the auth params from SBServer.
            let url = track.downloadURL()!
            let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: request)
            task.resume()
        }
    }
    
    override func finish() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SBSubsonicDownloadFinished"), object: activity)
        super.finish()
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Auth)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if (challenge.previousFailureCount == 0) {
            // snarf the server from here
            let track = self.threadedContext.object(with: trackID!) as! SBTrack
            
            let credential = URLCredential(user: track.server.username,
                                           password: track.server.password,
                                           persistence: .none)
            
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (State)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                NSApp.presentError(error)
            }
            self.finish()
            session.invalidateAndCancel()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Success
        activity.operationInfo = "Importing track..."
        
        // SBImportOperation needs an audio file extension. Rename the file.
        let fileType = UTType(mimeType: downloadTask.response?.mimeType ?? "audio/mp3") ?? UTType.mp3
        let temporaryFile = NSURL.temporaryFile()!.appendingPathExtension(for: fileType)
        try! FileManager.default.moveItem(at: location, to: temporaryFile)
        let temporaryFilePath = temporaryFile.path
        
        // Now import.
        if let importOperation = SBImportOperation(managedObjectContext: mainContext) {
            importOperation.filePaths = [temporaryFilePath]
            importOperation.copyFile = true
            importOperation.remove = true
            importOperation.libraryID = libraryID
            importOperation.remoteTrackID = trackID
            OperationQueue.sharedDownload().addOperation(importOperation)
        }
        
        self.finish()
        session.invalidateAndCancel()
    }
    
    // #MARK: -
    // #MARK: NSURLSession Delegate (Progress)
    
    private let byteCountFormatter = MeasurementFormatter()
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        activity.operationCurrent = NSNumber(value: bytesWritten)
        
        let totalWritten = Measurement<UnitInformationStorage>(value: Double(totalBytesWritten), unit: .bytes).converted(to: .megabytes)
        
        if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
            // If the expected content length is available, display percent complete.
            activity.indeterminated = false
            activity.operationTotal = NSNumber(value: totalBytesExpectedToWrite)
            
            let percentComplete = (Float(totalBytesExpectedToWrite) / Float(totalBytesExpectedToWrite)) * 100.0;
            activity.operationPercent = NSNumber(value: percentComplete)
            
            let totalToWrite = Measurement<UnitInformationStorage>(value: Double(totalBytesExpectedToWrite), unit: .bytes)
                .converted(to: .megabytes)
            activity.operationInfo = String.init(format: "Downloaded %@/%@",
                                                 byteCountFormatter.string(from: totalWritten),
                                                 byteCountFormatter.string(from: totalToWrite))
        } else {
            // If the expected content length is unknown, just log the progress.
            activity.indeterminated = true
            
            activity.operationInfo = String.init(format: "Downloaded %@",
                                                 byteCountFormatter.string(from: totalWritten))
        }
    }
}
