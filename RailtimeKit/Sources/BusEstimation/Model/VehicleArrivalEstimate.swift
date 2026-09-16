//
//  VehicleArrivalEstimate.swift
//  RailtimeKit
//
//  Created by Kai Quan Tay on 16/9/26.
//

import Foundation
import LTAAPI

/// A protocol for a generic vehicle's arrival
public protocol VehicleArrivalEstimate: Equatable, Identifiable, Codable {
    /// The ID for this bus (from Identifiable)
    var id: ID { get }

    // timing properties

    /// The estimated time of arrival
    var eta: Date { get }
    /// The error at the time of estimation. This will be plotted onto a standard deviation curve, with a standard deviation
    /// of half this value - this corresponds with a ~95% chance that the arrival will fall between `eta + error` and `eta - error`.
    var error: TimeDelta { get }

    // display properties

    /// The text to display on the UI. This should be short, preferably 3 characters or less.
    var displayText: String { get }
    /// The colour to display the vehicle as. This colour is used when the vehicle has not yet arrived.
    ///
    /// This is expected to be an RGB hexadecimal string in the format `"#RRGGBB"` or `"RRGGBB"`.
    var displayColor: String { get }
    /// The SF Symbol of the icon to display
    var displaySymbol: String { get }
    /// The source of the data
    var source: DataSource { get }

    // optional metadata
    /// The type for the metadata
    associatedtype Metadata = Void
    /// The metadata for this arrival estimate
    var metadata: Metadata { get }
}

/// Where the information for a bus' arrival comes from
public enum DataSource: Codable {
    /// The data was obtained directly from the LTA Live Bus API
    case live
    /// The data was projected from an up/downstream `live` bus
    case projected
    /// The data was extrapolated from the last known `live` or `projected` bus using known frequency data
    case extrapolated
}
