# Railtime_iOS

## Goals

Railtime intends to be a competitor with Google Maps and Citymapper. Its differentiating features are:
- Allowing the user to visualise transfers in a more intuitive manner
- Provide the user with the option to switch routes halfway through

## Architecture

Railtime uses a MVVM architecture:
- `Model`: The Model folder contains all data structures used between APIs and managers
- `Manager`: The Manager folder contains any classes that do logic on data and (optionally) hold state. Equivalent to "ViewModel" but I don't like that name.
- `View`: UI

## Packages

`RailtimeKit` contains three packages:

- `API`: LTAClient wraps LTA DataMall's REST API
- `BusEstimation`: A (mostly) stateless manager that can estimate bus timings given the LTA API, but only on a single route
- `Journey`: A stateful manager that holds the journey, and also "context" which is derived from Estimation.
