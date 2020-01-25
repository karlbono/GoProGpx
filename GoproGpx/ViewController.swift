//
//  ViewController.swift
//  GoproGpx
//
//  Created by Karl Bono on 22/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

import Cocoa
import MapKit

extension NSViewController {
    func useEntireScreen() {
        if let screen = NSScreen.main {
            let scFrame = screen.visibleFrame
            if let window = self.view.window {
                window.setFrame(NSRect(x: scFrame.minX, y: scFrame.minY, width: scFrame.maxX, height: scFrame.maxY), display: true)
            }
        }
    }
}

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, MKMapViewDelegate {
    
    var tracks: [GPSTrack] = []
    var wayPoints: [WayPointCollection] = []
    
    //mapview stuff
    @IBOutlet var mapView: MKMapView!

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let renderer = MKPolylineRenderer(polyline: polyline)
        if let gpsOverlay = overlay as? GPSTrackOverlay {
            renderer.strokeColor = gpsOverlay.track?.color
        } else {
            renderer.strokeColor = .black
        }
        renderer.lineWidth = 3
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation.isKind(of: MKWayPointAnnotation.self) {
            var annotationView: MKPinAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: "wayPointPin") as? MKPinAnnotationView
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "wayPointPin")
                annotationView?.canShowCallout = true
            }
            annotationView?.pinTintColor = .blue
            return annotationView
        }
        return nil
    }

    private func setMapScale() {
        let maxLon = tracks.map{$0.maxLongitude}.max() ?? 0.0
        let minLon = tracks.map{$0.minLongitude}.min() ?? 0.0
        let maxLat = tracks.map{$0.maxLatitude}.max() ?? 0.0
        let minLat = tracks.map{$0.minLatitude}.min() ?? 0.0
        let span = MKCoordinateSpan(latitudeDelta: (maxLat-minLat)*1.1, longitudeDelta: (maxLon-minLon)*1.1)
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (maxLat+minLat)/2, longitude: (maxLon+minLon)/2), span: span)
        mapView.setRegion(region, animated: true)
    }
    
    //tableview stuff
    @IBOutlet var mp4View: NSTableView!

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        var result:NSTableCellView
        result  = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as! NSTableCellView
        
        
        if tableColumn == tableView.tableColumns[0] {
            result.textField?.stringValue = tracks[row].name
        } else if tableColumn == tableView.tableColumns[1] {
            result.textField?.stringValue = "\(tracks[row].trackPoints.count)"
        }
        return result
    }
    
    // window setup stuff
    override func viewDidLoad() {
        mp4View.delegate = self
        mp4View.dataSource = self
        mapView.delegate = self
        mapView.mapType = .satellite
        super.viewDidLoad()
        // Do any additional setup after loading the view.

    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "Gopro GPX Extractor"
        let defaults = UserDefaults.standard
        authorNameField.stringValue = defaults.string(forKey: "Author") ?? ""
        authorURLField.stringValue = defaults.string(forKey: "AuthorURL") ?? ""
        authorDescriptionField.stringValue = defaults.string(forKey: "AuthorDescription") ?? ""
        for overlay in mapView.overlays {
            mapView.removeOverlay(overlay)
        }
        for track in tracks {
            mapView.addOverlay(GPSTrackOverlay(withTrack: track))
        }
        for annotation in mapView.annotations {
            mapView.removeAnnotation(annotation)
        }
        for wayPointCollection in wayPoints {
            for wayPoint in wayPointCollection.wayPoints {
                let wayPointAnnotation = MKWayPointAnnotation()
                wayPointAnnotation.coordinate = wayPoint.locationCoordinate2D
                wayPointAnnotation.title = wayPoint.name
                mapView.addAnnotation(wayPointAnnotation)
            }
        }
        mp4View.reloadData()
        setMapScale()
        useEntireScreen()
    }
    
    override func viewWillDisappear() {
        let defaults = UserDefaults.standard
        defaults.set(authorNameField.stringValue, forKey: "Author")
        defaults.set(authorURLField.stringValue, forKey: "AuthorURL")
        defaults.set(authorDescriptionField.stringValue, forKey: "AuthorDescription")
    }
    
    @IBOutlet var gpxNameField: NSTextField!
    
    @IBOutlet var authorNameField: NSTextField!
    @IBOutlet var authorDescriptionField: NSTextField!
    @IBOutlet var authorURLField: NSTextField!
    
    @IBOutlet var tracksNameField: NSTextField!
    @IBOutlet var tracksDescriptionField: NSTextField!
    @IBOutlet var tracksCommentField: NSTextField!
    @IBOutlet var tracksReductionToNumber: NSTextField!
    @IBOutlet var tracksReduceBox: NSButton!
    
    //button actions
    @IBAction func clearMP4List(_ sender: NSButton) {
        tracks.removeAll()
        mp4View.reloadData()
        for overlay in mapView.overlays {
            mapView.removeOverlay(overlay)
        }
    }
    
    @IBAction func addMP4(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["mp4","MP4"]
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                for nextURL in openPanel.urls {
                    let track = GPSTrack()
                    track.loadTrackPoints(from: nextURL.path)
                    self.tracks.append(track)
                    self.wayPoints.append(WayPointCollection())
                    track.color = NSColor(calibratedHue: CGFloat(Float(arc4random())/Float(UINT32_MAX)), saturation: 1, brightness: 1, alpha: 1.0)
                    self.mapView.addOverlay(GPSTrackOverlay(withTrack: track))
                }
                self.mp4View.reloadData()
                self.setMapScale()
            }
        }
        

    }
    
    func showAlert(message: String, info: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
    
    @IBAction func editTrack(_ sender: NSButton) {
        if let selectedTrack = mp4View?.selectedRow {
            if selectedTrack != -1 {
                if let editVC = self.storyboard?.instantiateController(withIdentifier: "trackEdit") as? trackEditController {
                    editVC.callingController = self
                    editVC.trackToEdit = tracks[selectedTrack]
                    editVC.wayPoints = wayPoints[selectedTrack]
                    self.view.window?.contentViewController = editVC
                }
                
            } else {
                _ = showAlert(message: "No track selected", info: "You have to select a track before editing it.")
            }
            
        }
    }
    
    @IBAction func generateGPX(_ sender: NSButton) {
        let gpx = GPX()
        gpx.name = gpxNameField.stringValue
        gpx.authorName = authorNameField.stringValue
        gpx.linkURL = authorURLField.stringValue
        gpx.linkDescription = authorDescriptionField.stringValue
        gpx.trackName = tracksNameField.stringValue
        gpx.trackDescription = tracksDescriptionField.stringValue
        gpx.trackComment = tracksCommentField.stringValue
        
        gpx.track.combine(tracks: tracks)
        gpx.track.color = .black

        if tracksReduceBox.state == .on {
            if let numberOfPoints = Int(tracksReductionToNumber.stringValue) {
                gpx.track = gpx.track.reduce(to: numberOfPoints)
            }
        }

        gpx.wayPointsCollection.combine(collections: wayPoints)
        
        for overlay in mapView.overlays {
            mapView.removeOverlay(overlay)
        }
        mapView.addOverlay(GPSTrackOverlay(withTrack: gpx.track))
        
        //save gpx file
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["gpx","GPX"]
        savePanel.nameFieldStringValue = gpx.name
        savePanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                if let fileURL = savePanel.url {
                    do {
                        try gpx.asString.write(to: fileURL, atomically: false, encoding: .utf8)
                    }
                    catch {/* error handling here */}
                }
            }
        }
    }
}
