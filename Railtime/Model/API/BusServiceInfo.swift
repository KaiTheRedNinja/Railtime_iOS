//
//  BusServiceInfo.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import Foundation

/// A single row from the 2.2 BusServices endpoint: static, frequency-level
/// information about a bus service.
struct BusServiceInfo: Codable {
    /// The bus service number, e.g. "15".
    let serviceNo: String
    /// The bus operator code, e.g. "SBST".
    let `operator`: String
    /// The direction of travel this frequency information applies to.
    let direction: Int
    /// The service category, e.g. "TRUNK".
    let category: String?
    /// The bus stop code of this service's origin.
    let originCode: String?
    /// The bus stop code of this service's destination.
    let destinationCode: String?
    /// AM peak dispatch frequency, formatted as a "lo-hi" minute band.
    let amPeakFreq: String?
    /// AM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    let amOffpeakFreq: String?
    /// PM peak dispatch frequency, formatted as a "lo-hi" minute band.
    let pmPeakFreq: String?
    /// PM off-peak dispatch frequency, formatted as a "lo-hi" minute band.
    let pmOffpeakFreq: String?
    /// Free-text description of the loop, if this service loops.
    let loopDesc: String?

    enum CodingKeys: String, CodingKey {
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
