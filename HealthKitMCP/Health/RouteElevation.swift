import Foundation

// MARK: - Route elevation computation helpers

func smoothAltitudes(_ altitudes: [Double], windowSize: Int = 5) -> [Double] {
    guard !altitudes.isEmpty else { return [] }

    let effectiveWindowSize = max(1, windowSize)
    let halfWindow = effectiveWindowSize / 2

    return altitudes.indices.map { index in
        let start = max(0, index - halfWindow)
        let end = min(altitudes.count - 1, index + halfWindow)
        let window = altitudes[start...end]
        return window.reduce(0, +) / Double(window.count)
    }
}

func computeRouteElevation(altitudes: [Double], thresholdMeters: Double = 0.05) -> (ascentFeet: Double, descentFeet: Double) {
    guard altitudes.count >= 2 else { return (0, 0) }

    let smoothedAltitudes = smoothAltitudes(altitudes)
    let metersToFeet = 3.28084
    var ascent = 0.0
    var descent = 0.0

    for i in 1..<smoothedAltitudes.count {
        let diff = smoothedAltitudes[i] - smoothedAltitudes[i - 1]
        if diff > thresholdMeters { ascent += diff }
        else if diff < -thresholdMeters { descent += abs(diff) }
    }

    return (ascent * metersToFeet, descent * metersToFeet)
}
