//
//  JourneyBuilderView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

import SwiftUI

struct JourneyBuilderView: View {
    @ObservedObject var manager: JourneyManager = try! .init()
    @State var showSheet: Bool = false

    @FocusState var focusedNode: UUID?

    @State var updateTask: Task<Void, any Error>?
    @State var showJourneyView: Bool = false

    var body: some View {
        List {
            Section {
                if let $startNode = $manager.journey.startNode.as(JourneyBusStopNode.self) {
                    HStack {
                        Text("Start code:")

                        ZStack(alignment: .trailing) {
                            let nodeId = $startNode.wrappedValue.id

                            Text((manager.context.nodeContext[nodeId] as? JourneyBusStopNode.Context)?.description ?? "")
                                .multilineTextAlignment(.trailing)
                                .opacity(focusedNode == nodeId ? 0.001 : 1)
                                .onTapGesture { focusedNode = nodeId }
                            TextField("Start code", text: $startNode.busStopCode)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedNode, equals: nodeId)
                                .opacity(focusedNode == nodeId ? 1 : 0.001)
                        }
                    }
                } else {
                    Text("Could not convert first node")
                }

                ForEach($manager.journey.legsErased, id: \.id, editActions: .delete) { $leg in
                    if let $busLeg = $leg.value.as(JourneyBusLeg.self) {
                        HStack {
                            TextField("Service no.", text: $busLeg.serviceNo)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity)

                            Text("to")

                            ZStack(alignment: .trailing) {
                                let nodeId = $busLeg.wrappedValue.destinationBusStop.id
                                Text((manager.context.nodeContext[nodeId] as? JourneyBusStopNode.Context)?.description ?? "")
                                    .multilineTextAlignment(.trailing)
                                    .opacity(focusedNode == nodeId ? 0.001 : 1)
                                    .onTapGesture { focusedNode = nodeId }
                                TextField("Stop code", text: $busLeg.destinationBusStop.busStopCode)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedNode, equals: nodeId)
                                    .opacity(focusedNode == nodeId ? 1 : 0.001)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        Text("Could not convert leg")
                    }
                }
            } footer: {
                Button {
                    manager.journey.legs.append(JourneyBusLeg(serviceNo: "", destinationBusStop: .init(busStopCode: "")))
                } label: {
                    Image(systemName: "plus")
                }
            }

            Section {
                HStack {
                    Button {
                        updateTask?.cancel()
                        updateTask = Task {
                            do {
                                try await manager.calculateJourney()
                            } catch {
                                print("Could not calculate journey: \(error)")
                            }
                        }
                    } label: {
                        Text("GO!")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Sample") {
                        guard let sample = manager.estimator.data.cache.read(
                            category: "user_input",
                            key: "sampleNodeContext",
                            as: JourneyContextSample.self
                        ) else {
                            print("No sample found")
                            return
                        }
                        manager.estimator.now = sample.saveDate
                        manager.context = sample.context
                    }
                    .buttonStyle(.bordered)
                }
                .listRowInsets(.all, 0)
                .listRowBackground(Color.clear)
            }

            if !manager.context.edgeContext.isEmpty {
                Section {
                    Button("Show sheet") {
                        showJourneyView = true
                    }
                    .sheet(isPresented: $showJourneyView) {
                        // TODO: adapt skewed journey view to new formats
                        JourneyDebugTimingsView(manager: manager)
                    }
                    Button("Save as sample") {
                        // save the leg context
                        manager.estimator.data.cache.write(
                            category: "user_input",
                            key: "sampleNodeContext",
                            data: JourneyContextSample(saveDate: .now, context: manager.context)
                        )
                    }
                }
                .onAppear {
                    showJourneyView = true
                }
            }
        }
        .onAppear {
            // load from cache
            let journey: Journey = manager.estimator.data.cache.read(category: "user_input", key: "journey") ?? .emptyBusJourney()
            manager.journey = journey
        }
        .onReceive(manager.$journey) { output in
            // save to cache
            manager.estimator.data.cache.write(category: "user_input", key: "journey", data: manager.journey)
            updateTask?.cancel()
            updateTask = Task {
                try await manager.updateStopContext()
            }
            print("Saved to cache")
        }
    }
}

struct JourneyDebugTimingsView: View {
    @ObservedObject var manager: JourneyManager

    @State var selectedLeg: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedLeg, let legContext = manager.context.edgeContext[selectedLeg] as? JourneyBusLeg.Context {
                    BusTimingsView(estimates: legContext.stopEstimations)
                } else {
                    Text("Please select a leg")
                }
            }
            .navigationTitle("DEBUG VISUALISER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Picker("", selection: $selectedLeg) {
                    ForEach(manager.journey.legsErased, id: \AnyJourneyLeg.id) { leg in
                        if let leg = leg.value as? JourneyBusLeg {
                            Text(leg.serviceNo)
                                .tag(leg.id)
                        }
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct JourneyContextSample: Codable {
    var saveDate: Date
    var context: JourneyContext
}

extension Binding where Value == any JourneyNode {
    func `as`<T: JourneyNode>(_ type: T.Type) -> Binding<T>? {
        if let value = self.wrappedValue as? T {
            .init(get: { value }, set: { self.wrappedValue = $0 })
        } else {
            nil
        }
    }
}

extension Binding where Value == any JourneyLeg {
    func `as`<T: JourneyLeg>(_ type: T.Type) -> Binding<T>? {
        if let value = self.wrappedValue as? T {
            .init(get: { value }, set: { self.wrappedValue = $0 })
        } else {
            nil
        }
    }
}
