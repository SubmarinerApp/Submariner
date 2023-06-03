//
//  SBTrackListLengthTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-03-21.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc(SBTrackListLengthTransformer) class SBTrackListLengthTransformer: ValueTransformer {
    private static let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter
    }()
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSArray.self // [SBTrack]
    }
    
    func timeLength(_ tracks: [SBTrack]) -> String? {
        let length = TimeInterval(tracks.map({ track in track.duration!.doubleValue}).reduce(0, +))
        let string = SBTrackListLengthTransformer.dateComponentsFormatter.string(from: length)
        return string
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if let tracks = value as? [SBTrack] {
            if tracks.count == 0 {
                return "No tracks"
            }
            let countAsString = SBTrackListLengthTransformer.numberFormatter.string(from: tracks.count as NSNumber)!
            // TODO: Proper plural forms with localization
            let tracksWord = tracks.count == 1 ? "track" : "tracks"
            
            let timeLength = timeLength(tracks)!
            // it's ok if it goes i.e. "1 hour, 3 minutes", AM does the same
            return String.localizedStringWithFormat("%@ %@, %@", countAsString, tracksWord, timeLength)
        } else {
            return ""
        }
    }
}
