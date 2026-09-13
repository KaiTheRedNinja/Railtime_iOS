//
//  LTABusServiceInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A single row from the 2.2 BusServices endpoint: static, frequency-level
/// information about a bus service.
public struct LTABusServiceInfo: Codable {
    /// The bus service number, e.g. "15".
    public let serviceNo: String
    /// The bus operator code, e.g. "SBST".
    public let `operator`: String
    /// The direction of travel this frequency information applies to.
    public let direction: Int
    /// The service category, e.g. "TRUNK".
    public let category: String?
    /// The bus stop code of this service's origin.
    public let originCode: String?
    /// The bus stop code of this service's destination.
    public let destinationCode: String?
    /// AM peak dispatch frequency, formatted as a "lo-hi" minute band.
    public let amPeakFreq: String?
    /// AM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    public let amOffpeakFreq: String?
    /// PM peak dispatch frequency, formatted as a "lo-hi" minute band.
    public let pmPeakFreq: String?
    /// PM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    public let pmOffpeakFreq: String?
    /// Free-text description of the loop, if this service loops.
    public let loopDesc: String?

    public enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case direction = "Direction"
        case category = "Category"
        case originCode = "OriginCode"
        case destinationCode = "DestinationCode"
        case amPeakFreq = "AM_Peak_Freq"
        case amOffpeakFreq = "AM_Offpeak_Freq"
        case pmPeakFreq = "PM_Peak_Freq"
        case pmOffpeakFreq = "PM_Offpeak_Freq"
        case loopDesc = "LoopDesc"
    }
}
