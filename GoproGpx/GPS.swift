//
//  GPS.swift
//  GoproGpx
//
//  Created by Karl Bono on 22/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

import Foundation
import MapKit

extension Date {
    struct Formatter {
        static let utcFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            dateFormatter.timeZone = TimeZone(identifier: "GMT")
            
            return dateFormatter
        }()
        static let timeFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            
            dateFormatter.dateFormat = "HH:mm:ss"
            dateFormatter.timeZone = TimeZone(identifier: "GMT")
            
            return dateFormatter
        }()
    }
    
    var toUTC: String {
        return Formatter.utcFormatter.string(from: self)
    }
    var toTime: String {
        return Formatter.timeFormatter.string(from: self)
    }
}

class GPSPoint: NSObject {
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var elevation: Double = 0.0
    var timestamp: Date
    
    init(fromData : GPS_data) {
        self.latitude = fromData.lat
        self.longitude = fromData.lon
        self.elevation = fromData.ele
        self.timestamp = Date(timeIntervalSince1970: fromData.time)
    }
    
    init(fromTrackPoint tp: GPSPoint) {
        self.latitude = tp.latitude
        self.longitude = tp.longitude
        self.elevation = tp.elevation
        self.timestamp = tp.timestamp
    }
    
    func toGPXTrack() -> String {
        var GPXEntry = ""
        GPXEntry.append("<trkpt lat=\"\(self.latitude)\"")
        GPXEntry.append(" lon=\"\(self.longitude)\">\n")
        GPXEntry.append("    <ele>\(self.elevation)</ele>\n")
        GPXEntry.append("    <time>\(self.timestamp.toUTC)</time>\n")
        GPXEntry.append("</trkpt>")
        return GPXEntry
    }
    
    var locationCoordinate2D: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    func squaredDistanceFrom(coord: CLLocationCoordinate2D) -> Double {
        let dLat = coord.latitude - latitude
        let dLon = coord.longitude - longitude
        return dLat * dLat + dLon * dLon
    }
}

class GPSTrackOverlay: MKPolyline {
    var track: GPSTrack? = nil
    convenience init(withTrack gpsTrack: GPSTrack) {
        var coords: [CLLocationCoordinate2D] = []
        for point in gpsTrack.trackPoints {
            coords.append(point.locationCoordinate2D)
        }
        self.init(coordinates: coords, count: coords.count)
        self.track = gpsTrack
    }
}

class GPSTrack: NSObject {
    var name: String = ""
    var trackPoints: [GPSPoint] = []
    var color: NSColor? = nil
    
    func combine(tracks: [GPSTrack]) {
        for track in tracks {
            self.trackPoints += track.trackPoints
        }
    }
    
    func getTrackPoints(from GPSData: UnsafeMutablePointer<GPS_data>?, forElements numberOfElements:Int) {
        if GPSData != nil {
            for index in 0..<numberOfElements {
                trackPoints.append(GPSPoint(fromData: GPSData![index]))
            }
        }
    }
    
    func loadTrackPoints(from fileName: String) {
        var numberOfElements: Int32 = 0
        name = fileName
        let cFileName = strdup(fileName)
        let GPSData = Create_GPS_data(cFileName, &numberOfElements)
        free(cFileName)
        getTrackPoints(from: GPSData, forElements: Int(numberOfElements))
    }
    
    var maxLongitude: Double {
        get {
            let maxLon = trackPoints.map{$0.longitude}.max()
            return maxLon ?? 0.0
        }
    }
    var maxLatitude: Double {
        get {
            let maxLat = trackPoints.map{$0.latitude}.max()
            return maxLat ?? 0.0
        }
    }
    var minLongitude: Double {
        get {
            let minLon = trackPoints.map{$0.longitude}.min()
            return minLon ?? 0.0
        }
    }
    var minLatitude: Double {
        get {
            let minLat = trackPoints.map{$0.latitude}.min()
            return minLat ?? 0.0
        }
    }

    var count: Int {
        get {
            return self.trackPoints.count
        }
    }
    
    func reduce(to numberOfPoints: Int) -> GPSTrack {
        // linear reduction
        let oldNumebrOfPoints = trackPoints.count
        if oldNumebrOfPoints > numberOfPoints {
            let numberOfPointsToEleminate = oldNumebrOfPoints - numberOfPoints
            let eleminationFraction = Double(oldNumebrOfPoints)/Double(numberOfPointsToEleminate)
            var nextElemination = eleminationFraction
            let newTrack = GPSTrack()
            for (index,currentPoint) in trackPoints.enumerated() {
                if Double(index+1) >= nextElemination {
                    nextElemination += eleminationFraction
                } else {
                    newTrack.trackPoints.append(currentPoint)
                }
            }
            return newTrack
        }
        return self
    }
    
    func reduceSelf(to numberOfPoints: Int) {
        let reductionResult = self.reduce(to: numberOfPoints)
        self.trackPoints = reductionResult.trackPoints
    }
    
    func closestTrackPointFrom(coord: CLLocationCoordinate2D) -> Int {
        let distances = trackPoints.map{$0.squaredDistanceFrom(coord: coord)}
        if let min = distances.min() {
            if let position = distances.firstIndex(of: min) {
                return position
            }
        }
        return 0
    }
}

class WayPoint: GPSPoint {
    var name = ""
    
    func toGPXWayPoint() -> String {
        var GPXEntry = ""
        GPXEntry.append("<wpt lat=\"\(latitude)\"")
        GPXEntry.append(" lon=\"\(longitude)\">\n")
        GPXEntry.append("    <ele>\(elevation)</ele>\n")
        GPXEntry.append("    <time>\(timestamp.toUTC)</time>\n")
        GPXEntry.append("    <name>\(name)</name>\n")
        GPXEntry.append("</wpt>")
        return GPXEntry
    }
}

class WayPointCollection: NSObject {
    var wayPoints: [WayPoint] = []
    
    func combine(collections: [WayPointCollection]) {
        for collection in collections {
            self.wayPoints += collection.wayPoints
        }
    }
}

class GPX: NSObject {
    var name = ""
    var authorName = ""
    var linkURL = ""
    var linkDescription = ""
    var trackName = ""
    var trackComment = ""
    var trackDescription = ""

    var track = GPSTrack()
    var wayPointsCollection = WayPointCollection()
    
    var asString: String {
        get {
            var gpxString = ""
            gpxString += """
            <?xml version="1.0" encoding="UTF-8"?><gpx creator="GoPro GPX Extractor - http://www.bono.be/software" version="1.1" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata><name>\(name)</name><author><name>\(authorName)</name></author><link href="\(linkURL)"><text>\(linkDescription)</text></link><time>\(Date().toUTC)</time></metadata>
            """
            
            for wayPoint in wayPointsCollection.wayPoints {
                gpxString += wayPoint.toGPXWayPoint()
            }

            gpxString += "<trk><name>\(trackName)</name><cmt>\(trackComment)</cmt><desc>\(trackDescription)</desc><trkseg>"

            for point in track.trackPoints {
                gpxString += point.toGPXTrack()
                gpxString += "\n"
            }
            
            gpxString += "</trkseg></trk></gpx>"
            return gpxString
        }
    }
}
