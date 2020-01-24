//
//  trackEditController.swift
//  GoproGpx
//
//  Created by Karl Bono on 28/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

import Cocoa
import MapKit

class MKWayPointAnnotation: MKPointAnnotation {
    
}

class trackEditController: NSViewController, MKMapViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSGestureRecognizerDelegate {

    var callingController: ViewController? = nil
    var trackToEdit: GPSTrack? = nil
    var wayPoints: WayPointCollection? = nil
    var selectedTrackpointAnnotation = MKPointAnnotation()
    
    @IBOutlet var mapView: MKMapView!
    
    @objc func mapClick(sender: NSClickGestureRecognizer? = nil) {
        if let locationPoint = sender?.location(in: mapView) {
            let coordPoint = mapView.convert(locationPoint, toCoordinateFrom: mapView)
            if let index = trackToEdit?.closestTrackPointFrom(coord: coordPoint) {
                trackView.selectRowIndexes([index], byExtendingSelection: false)
                trackView.scrollRowToVisible(index)
            }
        }
    }
    
    func setMapClickHandler() {
        let tap = NSClickGestureRecognizer(target: self, action: #selector(self.mapClick(sender:)))
        tap.numberOfClicksRequired = 1
        tap.delaysPrimaryMouseButtonEvents = false
        tap.delegate = self // This is not required
        mapView.addGestureRecognizer(tap)
    }
    
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
            //annotationView?.leftCalloutAccessoryView
            return annotationView
        }
        return nil
    }
    
    
    private func setMapScale() {
        if let trackToEdit = trackToEdit {
            let maxLon = trackToEdit.maxLongitude
            let minLon = trackToEdit.minLongitude
            let maxLat = trackToEdit.maxLatitude
            let minLat = trackToEdit.minLatitude
            let span = MKCoordinateSpan(latitudeDelta: (maxLat-minLat)*1.1, longitudeDelta: (maxLon-minLon)*1.1)
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (maxLat+minLat)/2, longitude: (maxLon+minLon)/2), span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    //tableview stuff
    @IBOutlet var trackView: NSTableView!
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let trackToEdit = trackToEdit {
            return trackToEdit.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        var result:NSTableCellView
        result  = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as! NSTableCellView
        
        if tableColumn == tableView.tableColumns[0] {
            result.textField?.stringValue = trackToEdit?.trackPoints[row].timestamp.toTime ?? "-"
        } else if tableColumn == tableView.tableColumns[1] {
            result.textField?.stringValue = "\(trackToEdit?.trackPoints[row].longitude ?? 0.0)"
        } else if tableColumn == tableView.tableColumns[2] {
            result.textField?.stringValue = "\(trackToEdit?.trackPoints[row].latitude ?? 0.0)"
        } else if tableColumn == tableView.tableColumns[3] {
            result.textField?.stringValue = "\(trackToEdit?.trackPoints[row].elevation ?? 0.0)"
        }
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let centerCoordinate = trackToEdit?.trackPoints[trackView.selectedRow].locationCoordinate2D {
            mapView.removeAnnotation(selectedTrackpointAnnotation)
            selectedTrackpointAnnotation.coordinate = centerCoordinate
            selectedTrackpointAnnotation.title = trackToEdit!.trackPoints[trackView.selectedRow].timestamp.toTime
            mapView.addAnnotation(selectedTrackpointAnnotation)
        }
    }
    
    override func viewDidLoad() {
        mapView.delegate = self
        mapView.mapType = .satellite
        trackView.dataSource = self
        trackView.delegate = self
        if let trackToEdit = trackToEdit {
            mapView.addOverlay(GPSTrackOverlay(withTrack: trackToEdit))
            setMapScale()
            setMapClickHandler()
        }
        if let wayPoints = wayPoints {
            for wayPoint in wayPoints.wayPoints {
                let wayPointAnnotation = MKWayPointAnnotation()
                wayPointAnnotation.coordinate = wayPoint.locationCoordinate2D
                wayPointAnnotation.title = wayPoint.name
                mapView.addAnnotation(wayPointAnnotation)
            }

        }
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "GPX Track Editor"
        useEntireScreen()
    }
    
    @IBAction func deletePressed(_ sender: NSButton) {
        for rowSelected in trackView.selectedRowIndexes.reversed() {
            if let trackToEdit = trackToEdit {
                trackToEdit.trackPoints.remove(at: rowSelected)
            }
        }
        trackView.reloadData()
        mapView.removeAnnotation(selectedTrackpointAnnotation)
        //TODO: redraw track
        for overlay in mapView.overlays {
            mapView.removeOverlay(overlay)
        }
        if let trackToEdit = trackToEdit {
            mapView.addOverlay(GPSTrackOverlay(withTrack: trackToEdit))
            //setMapScale()
        }
    }
    
    @IBAction func donePressed(_ sender: NSButton) {
        if let callingController = callingController {
            self.view.window?.contentViewController = callingController
        }
    }
    
    func inputWindow(title: String, message: String, info: String, defaultResponse: String) -> String {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let inputWC = storyboard.instantiateController(withIdentifier: "inputWindowController") as! NSWindowController
        if let inputWindow = inputWC.window {
            let vc = inputWindow.contentViewController as! InputViewController
            vc.titleLabel.stringValue = message
            vc.inputLabel.stringValue = info
            vc.inputField.stringValue = defaultResponse
            vc.windowTitle = title
            let application = NSApplication.shared
            application.runModal(for: inputWindow)
            let returnValue = vc.inputField.stringValue
            let okPressed = vc.didAccept
            inputWindow.close()
            if okPressed {
                return returnValue
            }
        }
        return ""
    }
    
    @IBAction func reducePressed(_ sender: Any) {
        
        let reduceToString = inputWindow(title: "Trackpoints", message: "The track contains \(trackToEdit?.count ?? 0) trackpoints. Less trackpoints will reduce file size.", info: "Reduce number of trackpoints to", defaultResponse: "\(trackToEdit?.count ?? 0)")
        
        if let reduceTo = Int(reduceToString) {
            trackToEdit?.reduceSelf(to: reduceTo)
            trackView.reloadData()
            for overlay in mapView.overlays {
                mapView.removeOverlay(overlay)
            }
            if let trackToEdit = trackToEdit {
                mapView.addOverlay(GPSTrackOverlay(withTrack: trackToEdit))
            }
        }
    }

    @IBAction func waypointPressed(_ sender: Any) {
        if trackView.selectedRow != -1 {
            if let selectedTrackPoint = trackToEdit?.trackPoints[trackView.selectedRow] {
                let waypointString = inputWindow(title: "Waypoints", message: "Insert waypoint at \(selectedTrackPoint.longitude)Lon, \(selectedTrackPoint.latitude)Lat.", info: "Waypoint name", defaultResponse: "")
                let newWaypoint = WayPoint(fromTrackPoint: selectedTrackPoint)
                newWaypoint.name = waypointString
                let wayPointAnnotation = MKWayPointAnnotation()
                wayPointAnnotation.coordinate = newWaypoint.locationCoordinate2D
                wayPointAnnotation.title = newWaypoint.name
                mapView.addAnnotation(wayPointAnnotation)
                mapView.selectAnnotation(wayPointAnnotation, animated: true)
                wayPoints?.wayPoints.append(newWaypoint)
            }
        }
    }
}
