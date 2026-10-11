# Railtime_iOS

## Goals

Railtime intends to be a competitor with Google Maps and Citymapper, but right now acts more like MyTransport. It allows you to:
- See nearby bus and MRT stops
- MRT stations:
  - How crowded the station is
  - The exits of the station
  - Nearby bus stops
- Bus stops:
  - List of bus services that go through that stop
  - The next 3 arrivals of each service

## Architecture

Railtime uses a MVVM architecture:
- `Model`: The Model folder contains all data structures used between APIs and managers
- `Manager`: The Manager folder contains any classes that do logic on data and (optionally) hold state. Equivalent to "ViewModel" but I don't like that name.
- `View`: UI

## Packages

`RailtimeKit` contains three packages:

- `API`: LTAClient wraps LTA DataMall's REST API
- `BusEstimation`: A (mostly) stateless manager that can estimate bus timings given the LTA API, but only on a single route

## Todo
- [x] Figure out how to optimise the display of things on maps UI
- [ ] A\* algorithm
  - [ ] Centralised list of bus and train stops
  - [ ] Figure out how to get the A\* algo working in the first place
- [ ] Get all addresses?
- [ ] Create UI for specifying navigation start/end
- [ ] Create UI for showing routes based on Xyrus's design
