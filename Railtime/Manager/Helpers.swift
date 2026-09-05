import Foundation

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

/// Returns "WD", "SAT", or "SUN" matching BusRoutes column prefixes.
///
/// - Parameter date: The date/time to classify.
/// - Returns: `"SAT"` for Saturday, `"SUN"` for Sunday, and `"WD"` (weekday)
///   for every other day.
func dayType(for date: Date) -> String {
    // Foundation's Gregorian `weekday` component is 1-indexed starting on
    // Sunday (1 = Sunday ... 7 = Saturday), unlike Python's
    // `datetime.weekday()` (0 = Monday ... 6 = Sunday), so the comparisons
    // below are shifted accordingly.
    let weekday = Calendar.current.component(.weekday, from: date)
    if weekday == 7 {
        return "SAT"
    }
    if weekday == 1 {
        return "SUN"
    }
    return "WD"
}

/// Great-circle distance in km. Optional cross-check helper (uses 2.4 stop
/// coordinates + live bus lat/long from 2.1).
///
/// - Parameters:
///   - lat1: Latitude of the first point, in degrees.
///   - lon1: Longitude of the first point, in degrees.
///   - lat2: Latitude of the second point, in degrees.
///   - lon2: Longitude of the second point, in degrees.
/// - Returns: The great-circle distance between the two points, in
///   kilometres.
func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let r = 6371.0
    let p1 = lat1 * .pi / 180
    let p2 = lat2 * .pi / 180
    let dphi = (lat2 - lat1) * .pi / 180
    let dlambda = (lon2 - lon1) * .pi / 180
    let a = sin(dphi / 2) * sin(dphi / 2) + cos(p1) * cos(p2) * sin(dlambda / 2) * sin(dlambda / 2)
    return 2 * r * asin(a.squareRoot())
}

/// Parses an ISO-8601 timestamp string (as returned by the BusArrival API's
/// `EstimatedArrival` field), mirroring Python's `datetime.fromisoformat`.
///
/// - Parameter ts: The timestamp string to parse. May be empty.
/// - Returns: The parsed `Date`, or `nil` if `ts` is empty or not parseable.
func parseISO(_ ts: String?) -> Date? {
    guard let ts, !ts.isEmpty else {
        return nil
    }
    // Try with fractional seconds first, then fall back to whole seconds,
    // matching the flexibility of Python's `datetime.fromisoformat`.
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: ts) {
        return date
    }
    let whole = ISO8601DateFormatter()
    whole.formatOptions = [.withInternetDateTime]
    return whole.date(from: ts)
}
