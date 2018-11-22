//
//  ViewController.swift
//  FindMyFriends
//
//  Created by Josh Hsieh on 2018/10/28.
//  Copyright © 2018 Josh. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
 
    @IBOutlet var tapMapCancelEditView: UITapGestureRecognizer!
    @IBOutlet weak var mainMapView: MKMapView!
    @IBOutlet weak var editPageView: UIView!
    @IBOutlet weak var refreshBtnView: UIBarButtonItem!
    @IBOutlet weak var editBtnView: UIBarButtonItem!
    @IBOutlet weak var updateUserLocationSwitchView: UISwitch!
    @IBOutlet weak var downloadFriendsSwitchView: UISwitch!
    @IBOutlet weak var drawUserLocationLineSwitchView: UISwitch!
    @IBOutlet weak var drawUserHistroyLocationLineSwitchView: UISwitch!
    
    // draw my history location line
    var myHistoryLocation: CLLocationCoordinate2D?
    var myNewLocation: CLLocationCoordinate2D?
    var myOldLocation: CLLocationCoordinate2D?
    // draw instant location line
    let logMyLocation = LogMyLocation()
    let logManager = LogManager()
    // singeton
    let communicator = Communicator.shared
    let locationManager = CLLocationManager()
    var incomingFriends = [FriendsInfo]()
    var userCoordinate: CLLocationCoordinate2D?
    var newCoordinate: CLLocationCoordinate2D? = nil
    // timer
    var timer01: Timer?
    var timer02: Timer?
    var timer03: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.title = "Find My Friends"
        
        // set edit button off
        updateUserLocationSwitchView.isOn = false
        downloadFriendsSwitchView.isOn = false
        drawUserLocationLineSwitchView.isOn = false
        drawUserHistroyLocationLineSwitchView.isOn = false
        // set edit pageView off
        editPageView.isHidden = true
        
        mainMapView.delegate = self
        mainMapView.showsUserLocation = true
        
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = true
        
        
        
        mainMapView.mapType = MKMapType(rawValue: 0)!
        // tracking user location and face diraction
        mainMapView.userTrackingMode = MKUserTrackingMode(rawValue: 2)!
        
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined || status == .denied || status == .authorizedWhenInUse {
            
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestAlwaysAuthorization()
        }
        // mylocation point diraction
        locationManager.startUpdatingHeading()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // 3 second move zoom in Map
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.moveAndZoomMap()
            
        }
    }
    
    // MARK: - Zoom in
    func moveAndZoomMap() {
        
        guard let location = locationManager.location else {
            print("Location is not ready")
            return
        }
        
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)
        mainMapView.setRegion(region, animated: true)
        
    }
    
    
    // Download freinds location
    @objc func doRefreshJob() {
        
        communicator.FreindsLocation(groupName: GROUPNAME) { (result, error) in
            if let error = error {
                print("FriendsLocation error: \(error)")
                return
            }
            guard let result = result else {
                print("result is nil")
                return
            }
            print("FriendsLocation OK.")

            guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) else {
                print("Fail to generate jsonData.")
                return
            }
            let decoder = JSONDecoder()
            guard let resultObject = try? decoder.decode(FriendsLocation.self, from: jsonData) else {
                print("Fail to decode jsonData.")
                return
            }
            //print("resultObject: \(resultObject)")
            guard let incomingFriends = resultObject.friendsInfo, !incomingFriends.isEmpty else {
                print("friendsInfo is nil or empty.")
                return
            }

            self.incomingFriends = incomingFriends

            // remove friends old loaction annotation
            self.mainMapView.removeAnnotations(self.mainMapView.annotations)
            // for in all friends data
            for friends in incomingFriends {
                // save all friends data in SQLite
                self.logManager.append(friends)
                // set annotations show my friends loaction
                let annotation = StoreAnnotation() //MKPointAnnotation()
                let showCoordinate =
                    CLLocationCoordinate2D(latitude: Double(friends.lat) ?? 0.0,longitude: Double(friends.lon) ?? 0.0)
                annotation.coordinate = showCoordinate
                annotation.title = "\(friends.friendName)"
                annotation.subtitle = "\(friends.lastUpdateDateTime)"
                self.mainMapView.addAnnotation(annotation)

            }
            // save my location from server
//            for myLocation in incomingFriends {
//                if myLocation.friendName == "Josh" {
//                    self.logManager.append(myLocation)
//                }
//            }
            

        }
        
    }
    
    // update my location to server & save
    @objc func doUpdateLocation() {
        
        let lat = Double((userCoordinate?.latitude)!)
        let lon = Double((userCoordinate?.longitude)!)
        
        let myLocation = MyLocation.init(lat: lat, lon: lon)
        self.logMyLocation.append(myLocation)
    
        communicator.UserLocation(lat: String(lat), lon: String(lon)) { (result, error) in
            if let error = error {
                print("update location fail: \(error)")
                return
            } else if let result = result {
                print("update location OK: \(result)")
            }
        }
        
    }
    
    // draw my histry loction line
    func doDrawHistoryLine() {
        
//        let startIndex: Int = {
//            var result = logMyLocation.count - 50
//            if result < 0 {
//                result = 0
//            }
//            return result
//        }()
        
        for i in 0..<(logMyLocation.count) {
            
            myOldLocation = myNewLocation
        
            guard let myDBLocation = logMyLocation.getMyLocation(at: i) else {
                assertionFailure("Fail to get message from logmanager.")
                continue
            }
            myHistoryLocation = CLLocationCoordinate2DMake(myDBLocation.lat, myDBLocation.lon)
            
            myNewLocation = myHistoryLocation
        
            guard let oldHistoryCoordinate = myOldLocation, let newHistoryCoordinate = myNewLocation else {
                continue
            }
            let area = [oldHistoryCoordinate, newHistoryCoordinate]
            let myPolyine = MKPolyline(coordinates: area, count: area.count)
            self.mainMapView.addOverlay(myPolyine)
            
        }
       
    }
    
    // instant draw my location line
    @objc func doDrawLocationLine() {
        
        // DrawLine
        guard let oldCoordinate = newCoordinate else {
            newCoordinate = userCoordinate
            return
        }
        newCoordinate = userCoordinate
        let area = [oldCoordinate, newCoordinate!]
        let myPolyine = MKPolyline(coordinates: area, count: area.count)
        self.mainMapView.addOverlay(myPolyine)
        
    }

    // control editPage close & editBtn open
    @IBAction func tapMapCancelEdit(_ sender: UITapGestureRecognizer) {
        editPageView.isHidden = true
        editBtnView.isEnabled = true
    }
    // refreshedBtn
    @IBAction func refreshBtnPressed(_ sender: UIBarButtonItem) {
        doUpdateLocation()
        doRefreshJob()
    }
    // control editPage open & editBtn close
    @IBAction func editBtnPressed(_ sender: UIBarButtonItem) {
        editPageView.isHidden = false
        editBtnView.isEnabled = false
    }
    // update my location to server for timer
    @IBAction func updateUserLocationSwitchPressed(_ sender: UISwitch) {

        if updateUserLocationSwitchView.isOn == true {
            timer01 = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(doUpdateLocation), userInfo: nil, repeats: true)
        } else {
            timer01?.invalidate()
            timer01 = nil
        }
    }
    // download friends date for timer
    @IBAction func downloadFriendsLocationSwitchPressed(_ sender: UISwitch) {
     
        if downloadFriendsSwitchView.isOn == true {
            timer02 = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(doRefreshJob), userInfo: nil, repeats: true)
        } else {
            timer02?.invalidate()
            timer02 = nil
        }
        
    }
    // draw my location line for timer
    @IBAction func drawUserLoactionLIneSwitchPressed(_ sender: UISwitch) {

        if drawUserLocationLineSwitchView.isOn == true {
            timer03 = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(doDrawLocationLine), userInfo: nil, repeats: true)
        } else {
            timer03?.invalidate()
            timer03 = nil
        }
    }
    // draw my histroy location line for timer
    @IBAction func drawUserHistroyLocationLineSwitchPressed(_ sender: UISwitch) {
        
        if drawUserHistroyLocationLineSwitchView.isOn == true {
            doDrawHistoryLine()
        } else {
            self.mainMapView.removeOverlays(self.mainMapView.overlays)
        }
    }
    
}

// mapCenterLocation
extension ViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let coordinate = mapView.region.center
        print("Map Center:\(coordinate.latitude), \(coordinate.longitude)")
        
    
    }
    
    // Drawline
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if (overlay is MKPolyline) {
            let lineView = MKPolylineRenderer(overlay: overlay)
            lineView.strokeColor = UIColor.red
            lineView.lineWidth = 5
            return lineView
        }
        return MKOverlayRenderer()
    }
    // set my annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

    guard let annotation = annotation as? StoreAnnotation else {
            assertionFailure("Fail to cast as StoreAnnotation.")
            return nil
        }
        let identifier = "store"

        var result = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView

        if result == nil {
            result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            result?.annotation = annotation
        }

        result?.canShowCallout = true
        result?.pinTintColor = .red
        result?.animatesDrop = true
        
        let button = UIButton(type: .detailDisclosure)
        button.addTarget(self, action: #selector(goToFreiendBtn(sender:)), for: .touchUpInside)
        result?.rightCalloutAccessoryView = button
        
        return result
    }
    // alert find my friends
    @objc
    func goToFreiendBtn(sender: Any) {
        
        let alert = UIAlertController(title: "導航前往找朋友", message: "確定導航嗎？", preferredStyle: .alert)
        
       
        let ok = UIAlertAction(title: "OK", style: .default) { (action) in
       
            let friendCoordinate = self.mainMapView.selectedAnnotations.first
            let lat = friendCoordinate?.coordinate.latitude
            let lon = friendCoordinate?.coordinate.longitude
            self.gotoFriend(latitude: lat!, longitude: lon!)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .destructive)
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        present(alert, animated: true)
    }
    // A to B
    func gotoFriend(latitude: Double, longitude: Double) {
        
        let sourceCoordinate = CLLocationCoordinate2DMake((userCoordinate?.latitude)!, (userCoordinate?.longitude)!)
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
   
        
        let targetCoordinate = CLLocationCoordinate2DMake(latitude, longitude)
        let targetPlacemark = MKPlacemark(coordinate: targetCoordinate)
        let targetMapItem = MKMapItem(placemark: targetPlacemark)
        
        let options = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        MKMapItem.openMaps(with: [sourceMapItem, targetMapItem], launchOptions: options)
    }

}

// userLocation
extension ViewController: CLLocationManagerDelegate {

     // my current locaion & save my location to SQLite
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

       
        guard let coordinate = locations.first?.coordinate else {
            assertionFailure("Invalid coordinate")
            return
        }
        print("Current Location: \(coordinate.latitude), \(coordinate.longitude)")
        
        userCoordinate = coordinate
        
//        let lat = coordinate.latitude as Double
//        let lon = coordinate.longitude as Double
//
//        let myLocation = MyLocation.init(lat: lat, lon: lon)
//        self.logMyLocation.append(myLocation)
//
    }

}


class StoreAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0)
    var title: String?
    var subtitle: String?
    
    override init() {
        super.init()
    }
}


struct FriendsLocation: Codable {
    var result: Bool
    var friendsInfo: [FriendsInfo]?
    
    enum CodingKeys: String, CodingKey {
        case result = "result"
        case friendsInfo = "friends"
    }
}





