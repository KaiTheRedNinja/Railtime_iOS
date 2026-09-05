import Foundation

// --------------------------------------------------------------------------
// Constants
// --------------------------------------------------------------------------

/// Base URL for every LTA DataMall OData service endpoint.
let BASE_URL = "https://datamall2.mytransport.sg/ltaodataservice"

/// LTA DataMall paginates most endpoints at 500 records.
let PAGE_SIZE = 500

/// What percentage of a bus's duration to a bus stop to use as debounce.
/// For example, if a bus is 5 minutes from station A and this value is 0.2,
/// station B which is 1 minute away will not be polled as we expect its
/// 3x next busses to be the same as station A's next 3 busses. This value
/// should not be set higher than 0.75 because it may cause desync at
/// large gaps between stations.
let STOP_GAP_PERCENTAGE = 0.4

/// The largest stop gap allowed, expressed in seconds (equivalent to the
/// Python `timedelta(minutes=15)`).
let MAX_STOP_GAP: TimeDelta = .mins(15)

/// When aligning one stop's projected window of up to-3 buses against the
/// already-known sequence, this is the max *average* per-pair time error
/// we'll accept for a candidate alignment before treating it as implausible.
/// Genuine schedule-projection noise should sit well under this; it exists
/// mainly to avoid confidently matching two windows that don't actually
/// correspond to the same buses.
///
/// Expressed in seconds (equivalent to the Python `timedelta(minutes=3)`).
let MAX_ALIGNMENT_ERROR: TimeDelta = .mins(3)
