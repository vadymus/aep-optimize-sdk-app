//
//  AppTrackingService.swift
/*
Copyright 2023 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import Foundation
import CoreLocation
//import AEPPlaces

protocol AppTrackingServiceDelegate {
    func didUpdateLocation(location: CLLocation)
    func locationDidFailWithError(error: Error)
    func didChangeAuthorization(status: CLAuthorizationStatus)
}

extension Notification.Name {
    static let didUpdateLocation = Notification.Name("didUpdateLocation")
    static let locationDidFailWithError = Notification.Name("locationDidFailWithError")
    static let didChangeAuthorization = Notification.Name("didChangeAuthorization")
}

class AppTrackingService : NSObject, CLLocationManagerDelegate{
    
    // Singleton instance
    static let shared = AppTrackingService()
    // Geo description converter
    static let geoCoder = CLGeocoder()
    // App's only location manager
    let locationManager: CLLocationManager = CLLocationManager()
    
    // last known visitor's location
    private(set) var currentLocation: CLLocation?
    // last known location for data load
    private(set) var prevDataLoadLocation: CLLocation?
    // permanent NYC center location
    static let staticNYCLocation: CLLocation! = CLLocation(latitude: 40.7589086, longitude: -73.985079)
    // preset Central Park location
    static let staticCentralParkColumbusCircleLocation: CLLocation! = CLLocation(latitude: 40.7682484, longitude:  -73.9814506)
    // is location manager started flag
    var isCurrentlyTracking = false
    var isBackgroundTracking = false
    // delegate
    internal var delegate: AppTrackingServiceDelegate?
    
    override init() {
        super.init()
        self.initialize()
    }
    
    deinit {
        self.stopTracking()
    }
    
    func initialize(){
        
        // ensure GPS update in the background continuously
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.pausesLocationUpdatesAutomatically = false
        // Indicator whether the status bar changes its appearance when an app uses location services in the background. This property affects only apps that received Always authorization.
        self.locationManager.showsBackgroundLocationIndicator = false
            
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.locationManager.distanceFilter = 10.0 //meters, slows down frequency
        self.locationManager.delegate = self
    }
    
    static func isLocationPermissionGranted() -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        return [.authorizedAlways, .authorizedWhenInUse].contains(CLLocationManager.authorizationStatus())
    }
    
    open func getCurrentLocation() -> CLLocation?{
        return self.currentLocation
    }
    
    open func getPrevDataLoadLocation() -> CLLocation?{
        return self.prevDataLoadLocation
    }
    
    open func setPrevDataLoadLocation(location: CLLocation) {
        self.prevDataLoadLocation = location
    }
    
    open func startTracking(){
        // Start location services update
        if self.isCurrentlyTracking == false {
            self.stopTrackingInBackground()
            self.locationManager.startUpdatingLocation()
            //self.locationManager.startUpdatingHeading()
            self.isCurrentlyTracking = true
            print("App Location Tracking Started")
        }else{
            print("App Location Tracking Was Already Started. No Action.")
        }
    }
    
    open func stopTracking(){
        self.locationManager.stopUpdatingLocation()
        //self.locationManager.stopUpdatingHeading()
        self.isCurrentlyTracking = false
        self.startTrackingInBackground()
    }
    
    open func startTrackingInBackground(){
        // Start location services update
        if self.isCurrentlyTracking == false {
            self.locationManager.startMonitoringVisits()
            self.isBackgroundTracking = true
            print("App Location Visit Monitoring Started")
        }else{
            print("App Location Visit Monitoring Was Already Started. No Action.")
        }
    }
    
    open func stopTrackingInBackground(){
        self.locationManager.stopMonitoringVisits()
        self.isBackgroundTracking = false
    }
    
    
    // MARK: Location Delegates
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        print("AppTrackingService didUpdateLocations \(location)")
        
        self.delegate?.didUpdateLocation(location: location)
        NotificationCenter.default.post(name: .didUpdateLocation, object: self, userInfo: ["location" : location])
        
        //TODO: not used yet - think of how to use it
        AppTrackingService.geoCoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placeDescription = placemarks?.first {
                print("placeDescription: \(placeDescription)")
            }
        }
        
        let oldLocation = self.currentLocation
        self.currentLocation = location
        
        // this is done in ViewController
        /*
         if self.currentLocation?.coordinate.latitude != oldLocation?.coordinate.latitude ||
            self.currentLocation?.coordinate.longitude != oldLocation?.coordinate.longitude {
            //self.recalculateDistanceFromCurrentLocation()
        }
        */
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        //? stop Updating Location?
        self.delegate?.locationDidFailWithError(error: error)
        NotificationCenter.default.post(name: .locationDidFailWithError, object: self, userInfo: ["error" : error])
        
        print("AppTrackingService didFailWithError \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        //let angle = CGFloat(newHeading.trueHeading).toRadians // convert from degrees to radians
        //print("didUpdateHeading angle \(angle)")
        
        /* // example how image moves based on location change
         UIView.animate(withDuration: 0.5) {
         let angle = newHeading.trueHeading.toRadians // convert from degrees to radians
         self.imageView.transform = CGAffineTransform(rotationAngle: angle) // rotate the picture
         }*/
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        
        let location = CLLocation.init(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        
        self.delegate?.didUpdateLocation(location: location)
        NotificationCenter.default.post(name: .didUpdateLocation, object: self, userInfo: ["location" : location])
        
        if visit.departureDate == Date.distantFuture {
            print("User arrived at location \(visit.coordinate) at time \(visit.arrivalDate)")
        } else {
            print("User departed location \(visit.coordinate) at time \(visit.departureDate)")
        }
    }
    
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("locationManager:didChangeAuthorization")
        switch status {
        case .restricted, .denied:
            // Disable your app's location features
            print("locationManager:didChangeAuthorization .restricted, .denied")
            break
        case .authorizedWhenInUse, .authorizedAlways:
            print("locationManager:didChangeAuthorization .authorizedWhenInUse, .authorizedAlways")
            break
        case .notDetermined:
            print("locationManager:didChangeAuthorization .notDetermined")
            break
        }
        self.delegate?.didChangeAuthorization(status: status)
    }
    
    // Calibaration fix http://stackoverflow.com/questions/17089155/compass-calibration-objective-c/18917110#18917110
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        if let h = manager.heading {
            return h.headingAccuracy < 0 || h.headingAccuracy > 10
        }
        return true
    }
    
    
    //TODO: Places ext
//    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
//        print("didEnterRegion \(region)")
//        ACPPlaces.processRegionEvent(region, for: .entry)
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
//        print("didExitRegion \(region)")
//        ACPPlaces.processRegionEvent(region, for: .exit)
//    }
    
}
