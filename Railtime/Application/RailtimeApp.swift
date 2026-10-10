//
//  RailtimeApp.swift
//  Railtime
//
//  Created by Kai Quan Tay on 5/9/26.
//

import SwiftUI

@main
struct RailtimeApp: App {
    @State private var manager = TransitMapManager(
        ltaService: LTAService(),
        locationManager: LocationManager()
    )

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
        }
    }
}
