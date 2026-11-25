import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoMetadata {
    private static func isDaliWatermark(_ value: String) -> Bool {
        value.hasPrefix("DALI1-") || value.hasPrefix("DALI2-")
    }

    static var software: String {
        "Dali Camera \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"))"
    }
    private static let exifFields = [
        "dateOriginal": "DateTimeOriginal", "timeZone": "OffsetTimeOriginal", "subsecond": "SubsecTimeOriginal",
        "lensMake": "LensMake", "lensModel": "LensModel", "exposureSeconds": "ExposureTime", "aperture": "FNumber",
        "iso": "ISOSpeedRatings", "exposureBias": "ExposureBiasValue", "exposureProgram": "ExposureProgram",
        "exposureMode": "ExposureMode", "meteringMode": "MeteringMode", "flash": "Flash", "focalLength": "FocalLength",
        "focalLength35mm": "FocalLenIn35mmFilm", "digitalZoom": "DigitalZoomRatio", "whiteBalance": "WhiteBalance", "colorSpace": "ColorSpace", "debug": "UserComment",
        "hiddenWatermark": "ImageUniqueID"
    ]
    private static let tiffFields = ["make": "Make", "model": "Model", "software": "Software", "artist": "Artist", "copyright": "Copyright", "description": "ImageDescription"]

    static func properties(data: Data) throws -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw NSError(domain: "Dali.Metadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo metadata unavailable"])
        }
        return properties
    }
    private static func properties(path: String) throws -> [String: Any] { try properties(data: Data(contentsOf: URL(fileURLWithPath: path))) }

    static func capture(path: String, at: Date, debug: String?) throws {
        var properties = try properties(path: path)
        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy:MM:dd HH:mm:ss"
        exif["DateTimeOriginal"] = exif["DateTimeOriginal"] ?? format.string(from: at)
        exif["DateTimeDigitized"] = exif["DateTimeDigitized"] ?? exif["DateTimeOriginal"]
        format.dateFormat = "XXXXX"
        let zone = format.string(from: at)
        exif["OffsetTimeOriginal"] = exif["OffsetTimeOriginal"] ?? (zone == "Z" ? "+00:00" : zone)
        exif["OffsetTimeDigitized"] = exif["OffsetTimeDigitized"] ?? exif["OffsetTimeOriginal"]
        format.dateFormat = "SSS"
        exif["SubsecTimeOriginal"] = exif["SubsecTimeOriginal"] ?? format.string(from: at)
        let payload: [String: Any]? = debug.flatMap { value in
            (try? JSONSerialization.jsonObject(with: Data(value.utf8))) as? [String: Any]
        }
        let hiddenWatermark = (payload?["hiddenWatermark"] as? String).flatMap { isDaliWatermark($0) ? $0 : nil }
        var debugPayload = payload
        debugPayload?.removeValue(forKey: "hiddenWatermark")
        debugPayload?.removeValue(forKey: "hiddenWatermarkPixels")
        exif["ImageUniqueID"] = hiddenWatermark
        if debugPayload?["schema"] as? String == "dali.capture-debug.v1",
           let data = try? JSONSerialization.data(withJSONObject: debugPayload ?? [:], options: [.sortedKeys]) {
            exif["UserComment"] = String(decoding: data, as: UTF8.self)
        } else {
            exif["UserComment"] = nil
        }
        properties[kCGImagePropertyExifDictionary as String] = exif
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff["Software"] = software
        properties[kCGImagePropertyTIFFDictionary as String] = tiff
        try write(properties, path: path)
    }

    static func copy(from source: String, to destination: String, captureEffectsApplied: Bool = false) throws {
        let original = try properties(path: source)
        var output = try properties(path: destination)
        let inputExif = original[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        var exif = output[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        for tag in Array(exifFields.values) + ["DateTimeDigitized", "OffsetTimeDigitized", "SubsecTimeDigitized"] { exif[tag] = inputExif[tag] }
        if captureEffectsApplied, let comment = inputExif["UserComment"] as? String,
           var debug = (try? JSONSerialization.jsonObject(with: Data(comment.utf8))) as? [String: Any],
           debug["schema"] as? String == "dali.capture-debug.v1" {
            debug["captureEffectsApplied"] = true
            if let data = try? JSONSerialization.data(withJSONObject: debug, options: [.sortedKeys]) {
                exif["UserComment"] = String(decoding: data, as: UTF8.self)
            }
        }
        exif["PixelXDimension"] = output[kCGImagePropertyPixelWidth as String]
        exif["PixelYDimension"] = output[kCGImagePropertyPixelHeight as String]
        let inputTiff = original[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        var tiff = output[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        for tag in tiffFields.values { tiff[tag] = inputTiff[tag] }
        tiff["Software"] = software
        tiff["Orientation"] = 1
        output[kCGImagePropertyOrientation as String] = 1
        output[kCGImagePropertyExifDictionary as String] = exif
        output[kCGImagePropertyTIFFDictionary as String] = tiff
        output[kCGImagePropertyGPSDictionary as String] = original[kCGImagePropertyGPSDictionary as String]
        try write(output, path: destination)
    }

    static func edit(from source: String, to destination: String, metadata: [String: Any]) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
        var properties = try properties(path: destination)
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        for (name, tag) in [
            "description": "ImageDescription", "artist": "Artist", "copyright": "Copyright",
            "software": "Software", "make": "Make", "model": "Model"
        ] {
            guard let raw = metadata[name] as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            tiff[tag] = value.isEmpty ? nil : value
        }
        properties[kCGImagePropertyTIFFDictionary as String] = tiff
        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        for (name, tag) in [
            "dateOriginal": "DateTimeOriginal", "timeZone": "OffsetTimeOriginal", "subsecond": "SubsecTimeOriginal",
            "lensMake": "LensMake", "lensModel": "LensModel"
        ] {
            guard let raw = metadata[name] as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            exif[tag] = value.isEmpty ? nil : value
            if name == "dateOriginal" { exif["DateTimeDigitized"] = value.isEmpty ? nil : value }
            if name == "timeZone" { exif["OffsetTimeDigitized"] = value.isEmpty ? nil : value }
            if name == "subsecond" { exif["SubsecTimeDigitized"] = value.isEmpty ? nil : value }
        }
        for (name, tag) in [
            "exposureSeconds": "ExposureTime", "aperture": "FNumber", "exposureBias": "ExposureBiasValue",
            "focalLength": "FocalLength", "digitalZoom": "DigitalZoomRatio"
        ] {
            guard let raw = metadata[name] as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            exif[tag] = value.isEmpty ? nil : Double(value)
        }
        for (name, tag) in [
            "exposureProgram": "ExposureProgram", "exposureMode": "ExposureMode", "meteringMode": "MeteringMode",
            "flash": "Flash", "focalLength35mm": "FocalLenIn35mmFilm", "whiteBalance": "WhiteBalance", "colorSpace": "ColorSpace"
        ] {
            guard let raw = metadata[name] as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            exif[tag] = value.isEmpty ? nil : Int(value)
        }
        if let raw = metadata["iso"] as? String {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            exif["ISOSpeedRatings"] = value.isEmpty ? nil : Int(value).map { [$0] }
        }
        if let raw = metadata["hiddenWatermark"] as? String {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            exif["ImageUniqueID"] = isDaliWatermark(value) ? value : nil
        }
        properties[kCGImagePropertyExifDictionary as String] = exif
        if metadata["latitude"] != nil || metadata["longitude"] != nil || metadata["altitude"] != nil {
            var gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
            let latitude = (metadata["latitude"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let longitude = (metadata["longitude"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if latitude.isEmpty && longitude.isEmpty {
                for tag in ["Latitude", "LatitudeRef", "Longitude", "LongitudeRef"] { gps[tag] = nil }
            } else if let lat = Double(latitude), let lon = Double(longitude) {
                gps["Latitude"] = abs(lat)
                gps["LatitudeRef"] = lat < 0 ? "S" : "N"
                gps["Longitude"] = abs(lon)
                gps["LongitudeRef"] = lon < 0 ? "W" : "E"
            }
            if let raw = metadata["altitude"] as? String {
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if let altitude = Double(value) {
                    gps["Altitude"] = abs(altitude)
                    gps["AltitudeRef"] = altitude < 0 ? 1 : 0
                } else if value.isEmpty {
                    gps["Altitude"] = nil
                    gps["AltitudeRef"] = nil
                }
            }
            properties[kCGImagePropertyGPSDictionary as String] = gps.isEmpty ? nil : gps
        }
        try write(properties, path: destination)
    }

    static func read(_ properties: [String: Any]) -> [String: Any] {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        var result: [String: Any] = [:]
        for (name, tag) in exifFields { result[name] = exif[tag] }
        if let iso = exif["ISOSpeedRatings"] as? [NSNumber] { result["iso"] = iso.first }
        for (name, tag) in tiffFields { result[name] = tiff[tag] }
        result["width"] = properties[kCGImagePropertyPixelWidth as String]
        result["height"] = properties[kCGImagePropertyPixelHeight as String]
        result["orientation"] = properties[kCGImagePropertyOrientation as String] ?? 1
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps["Latitude"] as? NSNumber, let lon = gps["Longitude"] as? NSNumber {
            result["latitude"] = lat.doubleValue * ((gps["LatitudeRef"] as? String) == "S" ? -1 : 1)
            result["longitude"] = lon.doubleValue * ((gps["LongitudeRef"] as? String) == "W" ? -1 : 1)
            if let altitude = gps["Altitude"] as? NSNumber { result["altitude"] = altitude.doubleValue * ((gps["AltitudeRef"] as? NSNumber)?.intValue == 1 ? -1 : 1) }
        }
        return result
    }

    static func capturedDate(path: String) -> Date? {
        guard let properties = try? properties(path: path), let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any], let date = exif["DateTimeOriginal"] as? String else { return nil }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        if let offset = exif["OffsetTimeOriginal"] as? String {
            format.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
            return format.date(from: date + offset)
        }
        format.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return format.date(from: date)
    }

    private static func write(_ properties: [String: Any], path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw NSError(domain: "Dali.Metadata", code: 2) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw NSError(domain: "Dali.Metadata", code: 3) }
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "Dali.Metadata", code: 4) }
        try (data as Data).write(to: url, options: .atomic)
    }
}
