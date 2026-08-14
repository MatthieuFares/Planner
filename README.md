# Planner

Planner is a full-stack project management and scheduling application designed to handle complex project planning workflows through an interactive Gantt interface.

The project started in **2025** and is currently functional, with deployment preparation still in progress.

## Overview

Planner aims to provide project planning features commonly found in professional scheduling tools while keeping a modern and modular architecture.

The application covers the complete development stack:

* project and task management
* interactive Gantt planning
* task dependencies
* resource allocation
* project calendars
* critical path calculation
* schedule baselines and versions
* project monitoring and analysis

## Tech Stack

### Backend

* C#
* .NET / ASP.NET Core
* REST API
* Entity Framework Core
* SQL Server
* OpenAPI / Swagger

### Frontend

* Flutter
* Dart
* Dio

### Other features

* XML / MSPDI file import
* PDF generation and printing
* secure client-side storage
* configurable deployment environments

## Architecture

```text
Flutter application
        |
        | REST API
        v
ASP.NET Core API
        |
        | Entity Framework Core
        v
    SQL Server
```

The frontend and backend are kept separate so that each part of the application can evolve independently.

## Main Features

### Project planning

* Project and task creation
* Interactive Gantt chart
* Task hierarchy and planning items
* Start and end date management

### Dependencies

Planner supports the main scheduling dependency types:

* Finish-to-Start (FS)
* Start-to-Start (SS)
* Finish-to-Finish (FF)
* Start-to-Finish (SF)

Dependencies can also include scheduling offsets.

### Scheduling

* Project calendars
* Working periods
* Calendar exceptions
* Critical path calculation
* Delay and schedule warning detection

### Resource management

* Resource creation and management
* Resource assignments
* Resource groups
* Resource analysis

### Project tracking

* Schedule baselines
* Planning versions
* Project summaries
* Warnings and analysis views

## Project Structure

```text
Planner/
├── Controllers/       REST API endpoints
├── DTOs/              API data transfer objects
├── Data/              Database context and configuration
├── Models/            Domain and persistence models
├── Services/          Business logic
├── Migrations/        Entity Framework migrations
├── planner_front/     Flutter client application
└── DEPLOYMENT.md      Deployment configuration
```

## Running the Project

### Requirements

* .NET SDK
* SQL Server
* Flutter SDK

### Backend

```bash
dotnet restore
dotnet run
```

The SQL Server connection string can be configured through `appsettings.json` for local development or through environment variables.

### Flutter application

```bash
cd planner_front
flutter pub get
flutter run -d chrome
```

A custom API endpoint can be provided using:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5120/api
```

## Screenshots

Screenshots of the Gantt view, dashboards and resource management interface will be added as the public presentation of the project is finalized.

## Status

**Functional — active development**

The core planning application is usable locally. Current work focuses on feature completion, interface improvements and deployment preparation.

## Author

**Matthieu Fares**

Software Developer — C# / .NET
GitHub: [MatthieuFares](https://github.com/MatthieuFares)
