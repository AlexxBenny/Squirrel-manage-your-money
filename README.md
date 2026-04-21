# Squirrel — Manage Your Money

Squirrel is a Flutter-based personal finance tracker focused on helping you manage spending, budgets, portfolio holdings, and financial insights in one place.

## Features

- Dashboard with spending/income overview
- Transaction tracking with categories
- Budget setup and progress monitoring
- Portfolio holdings management
- Analytics screen for trends and breakdowns
- Local data persistence using SQLite
- Data export support (CSV/JSON)

## Tech Stack

- Flutter (Dart)
- Provider (state management)
- SQLite (`sqflite`)
- `fl_chart` for visual analytics

## Project Structure

```text
lib/
  core/         # constants, theme, utils, database, services
  models/       # data models (transactions, budgets, holdings, reminders)
  providers/    # app state providers
  screens/      # feature screens (dashboard, transactions, budget, etc.)
  widgets/      # reusable UI components
```

## Getting Started

### Prerequisites

- Flutter SDK (compatible with Dart SDK `^3.6.0`)
- Android Studio / Xcode (for mobile targets)

### Installation

```bash
git clone https://github.com/AlexxBenny/Squirrel-manage-your-money.git
cd Squirrel-manage-your-money
flutter pub get
```

### Run the App

```bash
flutter run
```

### Development Checks

```bash
flutter analyze
flutter test
```

## Platforms

This repository includes Flutter platform folders for:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

## License

No license file is currently included in this repository.
