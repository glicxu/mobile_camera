import CoreLocation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// All collection state is main-thread confined; capture snapshots the fix.
final class PhotoLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var enabled = false
    private var active = false
    private var latest: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func configure(enabled: Bool, requestPermission: Bool) -> String {
        self.enabled = enabled
        refresh()
        if enabled && requestPermission && manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if !enabled { return "off" }
        if !CLLocationManager.locationServicesEnabled() { return "servicesDisabled" }
        if !authorized { return "permissionDenied" }
        if current() == nil { return "waiting" }
        return manager.accuracyAuthorization == .reducedAccuracy ? "approximate" : "ready"
    }

    private var authorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    func setActive(_ value: Bool) { active = value; refresh() }

    private func refresh() {
        if enabled && active && authorized {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
            latest = nil
        }
    }

    func current() -> CLLocation? {
        guard enabled, active, authorized, CLLocationManager.locationServicesEnabled(), let location = latest,
              location.horizontalAccuracy >= 0, CLLocationCoordinate2DIsValid(location.coordinate),
              (-120.0...0.0).contains(location.timestamp.timeIntervalSinceNow) else { return nil }
        return location
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { refresh() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if enabled && active { latest = locations.last }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { latest = nil }

    static func tag(_ location: CLLocation, path: String) throws {
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.timeZone = TimeZone(secondsFromGMT: 0)
        date.dateFormat = "yyyy:MM:dd"
        let day = date.string(from: location.timestamp)
        date.dateFormat = "HH:mm:ss.SSS"
        var gps: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: abs(location.coordinate.latitude),
            kCGImagePropertyGPSLatitudeRef as String: location.coordinate.latitude < 0 ? "S" : "N",
            kCGImagePropertyGPSLongitude as String: abs(location.coordinate.longitude),
            kCGImagePropertyGPSLongitudeRef as String: location.coordinate.longitude < 0 ? "W" : "E",
            kCGImagePropertyGPSDateStamp as String: day,
            kCGImagePropertyGPSTimeStamp as String: date.string(from: location.timestamp),
        ]
        if location.verticalAccuracy >= 0 {
            gps[kCGImagePropertyGPSAltitude as String] = abs(location.altitude)
            gps[kCGImagePropertyGPSAltitudeRef as String] = location.altitude < 0 ? 1 : 0
        }
        try write(gps: gps, path: path)
    }

    private static func gps(path: String) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        return properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
    }

    static func copyGPS(from source: String, to destination: String) throws {
        if let gps = gps(path: source) { try write(gps: gps, path: destination) }
    }

    static func location(path: String) -> CLLocation? {
        guard let gps = gps(path: path),
              let latitude = gps[kCGImagePropertyGPSLatitude as String] as? NSNumber,
              let longitude = gps[kCGImagePropertyGPSLongitude as String] as? NSNumber else { return nil }
        let lat = latitude.doubleValue * ((gps[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" ? -1 : 1)
        let lon = longitude.doubleValue * ((gps[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" ? -1 : 1)
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private static func write(gps: [String: Any], path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw NSError(domain: "Dali.PhotoLocation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read photo metadata"])
        }
        properties[kCGImagePropertyGPSDictionary as String] = gps
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Dali.PhotoLocation", code: 2)
        }
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "Dali.PhotoLocation", code: 3) }
        try (output as Data).write(to: url, options: .atomic)
    }
}
