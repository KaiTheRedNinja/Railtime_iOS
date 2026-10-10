//
//  JourneyBuilderView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 12/9/26.
//

/*
import SwiftUI
import Journey
import BusEstimation
import LTAAPI

struct JourneyBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var manager: JourneyManager = .init()
    @State var showSheet: Bool = false

    @FocusState var focusedNode: JourneyNodeID?

    @State var updateTask: Task<Void, any Error>?
    @State var showJourneyView: Bool = false
    @AppStorage("LTA_ACCOUNT_KEY") var accountKey: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        SecureField("Account Key", text: $accountKey)
                        Button("Save") {
                            manager.updateAPIKey(accountKey)
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("LTA Account Key")
                }

                Section {
                    if let $startNode = $manager.journey.startNode.as(JourneyBusStopNode.self) {
                        HStack {
                            Text("Start code:")

                            ZStack(alignment: .trailing) {
                                let nodeId = $startNode.wrappedValue.id

                                Text(manager.context.context(forNode: $startNode.wrappedValue, type: JourneyBusStopNode.self)?.description ?? "")
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

                    ForEach(manager.journey.path.enumerated(), id: \.offset) { (_, pathItem) in
                        if let $legAndNode = $manager.journey.legAndEndNode(
                            for: pathItem,
                            legAs: JourneyBusLeg.self,
                            nodeAs: JourneyBusStopNode.self
                        ) {
                            HStack {
                                TextField("Service no.", text: $legAndNode.leg.serviceNo)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity)

                                Text("to")

                                ZStack(alignment: .trailing) {
                                    let nodeId = $legAndNode.wrappedValue.endNode.id
                                    Text(manager.context.context(forNode: $legAndNode.wrappedValue.endNode, type: JourneyBusStopNode.self)?.description ?? "")
                                        .multilineTextAlignment(.trailing)
                                        .opacity(focusedNode == nodeId ? 0.001 : 1)
                                        .onTapGesture { focusedNode = nodeId }
                                    TextField("Stop code", text: $legAndNode.endNode.busStopCode)
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
                } header: {
                    Text("Bus Trip Plan")
                } footer: {
                    HStack {
                        Button {
                            // create the new end stop
                            let newEndStop = JourneyBusStopNode(busStopCode: "", nextLegIds: [])
                            let newLeg = JourneyBusLeg(serviceNo: "", destinationId: newEndStop.id)

                            // link it to the current last item
                            let lastNodeId = if let lastPathItem = manager.journey.path.last,
                                                let lastLeg = manager.journey.legs[lastPathItem] {
                                lastLeg.destinationId
                            } else {
                                manager.journey.startNodeId
                            }
                            manager.journey.nodes[lastNodeId]?.nextLegIds.append(newLeg.id)

                            manager.journey.nodes[newEndStop.id] = newEndStop
                            manager.journey.legs[newLeg.id] = newLeg
                            manager.journey.path.append(newLeg.id)
                            manager.journey.removeUnconnected()
                        } label: {
                            Image(systemName: "plus")
                        }

                        Spacer()

                        Button {
                            manager.journey = Journey.sampleJourney
                            manager.context = .empty
                        } label: {
                            Image(systemName: "arrow.trianglehead.branch")
                        }
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
                            guard let estimator = manager.estimator,
                                  let sample = estimator.data.diskCache.read(
                                      category: "user_input",
                                      key: "sampleNodeContext",
                                      as: JourneyContextSample.self
                                  ) else {
                                print("No sample or estimator found")
                                return
                            }
                            estimator.now = sample.saveDate
                            manager.context = sample.context

                            print("Loaded sample saved at \(estimator.now)")
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
                            let now = manager.estimator?.now ?? .now
                            JourneyVisualiser(manager: manager, now: now)
                        }
                        Button("Save as sample") {
                            if let estimator = manager.estimator {
                                estimator.data.diskCache.write(
                                    category: "user_input",
                                    key: "sampleNodeContext",
                                    data: JourneyContextSample(saveDate: .now, context: manager.context)
                                )
                            }
                        }
                    }
                    .onAppear {
                        showJourneyView = true
                    }
                }
            }
            .navigationTitle("Plan Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let estimator = manager.estimator {
                    let journey: Journey = estimator.data.diskCache.read(category: "user_input", key: "journey") ?? .emptyBusJourney()
                    manager.journey = journey
                }
            }
            .onReceive(manager.$journey) { output in
                if let estimator = manager.estimator {
                    estimator.data.diskCache.write(category: "user_input", key: "journey", data: manager.journey)
                }
                updateTask?.cancel()
                updateTask = Task {
                    try await manager.updateStopContext()
                }
            }
        }
    }
}

struct JourneyDebugTimingsView: View {
    @ObservedObject var manager: JourneyManager

    @State var selectedLegContextId: JourneyLegContextID?

    var now: Date

    var body: some View {
        NavigationStack {
            Group {
                if let selectedLegContextId,
                   let legContext = manager.context.context(
                       forLegContextId: selectedLegContextId,
                       type: JourneyBusLeg.self
                   ) {
                    BusTimingsView(estimates: legContext.stopEstimations, now: now)
                } else {
                    Text("Please select a leg")
                }
            }
            .navigationTitle("DEBUG VISUALISER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Picker("", selection: $selectedLegContextId) {
                    ForEach(manager.journey.legs.values.map { AnyJourneyLeg(value: $0) }, id: \.id) { leg in
                        if let leg = leg.value as? JourneyBusLeg {
                            Text(leg.serviceNo)
                                .tag(leg.contextId)
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
*/
