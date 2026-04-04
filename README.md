# Finance Companion (Mobile-Only Assessment Submission)

This repository contains the mobile-only version of my personal finance app, prepared specifically for the internship screening assignment.

The app is built with Flutter and focuses on product usability, organized architecture, and local-first data handling.

## Assignment Context

The assignment allows submitting an already-built similar app, as long as the submission clearly explains how it relates to the requested requirements.

This submission is an adapted version of my previous full-stack project:

- Original full-stack repository (reference): https://github.com/kalutm/finance_tracker

This repo is intentionally mobile-only and renamed/presented as **Finance Companion** for assessment.

## How This Mobile Submission Relates To The Original Project

Starting point:

- The original project included Flutter frontend + FastAPI backend.

What I changed for this assessment-focused mobile submission:

- Separated and submitted mobile app code only.
- Migrated core CRUD/data flows from API-based access to local persistence (Hive).
- Refined navigation and screen responsibilities to match assessment expectations.
- Added and polished a dedicated budget feature as the goal/challenge functionality.
- Refocused analytics/insights for better pattern visibility on small screens.
- Added optional biometric app lock with in-app settings toggle.
- Added a one-tap demo-data seeding action in Settings for quick testing/demo setup.
- Preserved and polished dark mode and mobile-friendly interactions.

## Repository Link (Assessment Submission)

- Mobile-only assessment repository: https://github.com/kalutm/zorvyn_finance_companion

## Build / Demo Links

- Android build artifact (APK): https://github.com/kalutm/zorvyn_finance_companion/releases/tag/finance_companion
- Demo video: `<<PASTE_DEMO_VIDEO_LINK_HERE>>`

## Screenshots Placeholder

Add screenshots below before submission.

### Home Dashboard

![Screenshot_20260404_223648](https://github.com/user-attachments/assets/2dcf1871-c1c6-463e-9eaa-28b3f6471165)

### Transactions (List + Form + Filters)

![Screenshot_20260404_223657](https://github.com/user-attachments/assets/0d87d0b3-92a9-408d-b56c-f0293ce39465)
<img width="591" height="1280" alt="image" src="https://github.com/user-attachments/assets/a18b3721-7a81-43ae-85f8-c9ae851e76cf" />

### Budget Feature

![Screenshot_20260404_223725](https://github.com/user-attachments/assets/4615179f-88ea-4606-9c06-959b5b2f3bae)

### Report & Anlytics Screen

![Screenshot_20260404_223757](https://github.com/user-attachments/assets/5bdc9a23-22c1-4efa-90fc-bd54932940f6)

### Settings (Dark Mode + Biometric Toggle)

![Screenshot_20260404_223804](https://github.com/user-attachments/assets/cb86af6f-0ae8-4a2d-aa79-120c2ac1689f)

## Project Overview

**Finance Companion** is a lightweight personal finance mobile app that helps users:

- Track income and expenses.
- Organize accounts and categories.
- Understand spending behavior through insights.
- Stay goal-oriented with a budget tracker.

The app is designed for everyday use with simple navigation, focused screens, and practical local data handling.

## Requirement Coverage Mapping

### 1. Home Dashboard

- Summary information and overview metrics are shown in the transaction/home experience.
- Includes visual and analytical components (trend/category breakdown/progress-focused cards).
- Designed to balance information density and readability.

### 2. Transaction Tracking

- Add, view, edit, and delete transaction flows are implemented.
- Transaction data includes amount, type, category, date, account, and description/notes.
- Filtering and search are supported, including direct local-source filtering.

### 3. Goal / Challenge Feature

- Implemented feature: **Budget Limit Tracker**.
- Users can create budget limits and monitor spend progress/warnings.

### 4. Insights Screen

- Dedicated insights screen focuses on behavior and patterns such as:
	- highest spending category,
	- week-vs-week comparison,
	- monthly trend,
	- category-based spending breakdown,
	- frequent transaction type.

### 5. Smooth Mobile UX

- Drawer-based navigation between major sections.
- Form-centric flows for data entry.
- Loading/empty/error states across modules.
- Touch-friendly interaction patterns and modal workflows.

### 6. Local Data Handling / API Integration

- This submission uses **local persistence (Hive)** for consistency and offline-friendly behavior.
- App logic is structured around service/data-source abstractions.

### 7. Code Structure and State Management

- Feature-first structure with domain/data/presentation separation.
- State handled via **BLoC/Cubit** and Riverpod providers where appropriate.
- Reusable UI components and modular feature organization.

### Optional Enhancements Included

- Dark mode.
- Biometric lock (optional toggle in settings).
- Multi-currency-aware summaries in budget calculations.
- Demo seed utility from Settings to populate realistic sample accounts/categories/budgets/transactions.

## Documentation Notes

This README intentionally includes:

- Setup and run instructions.
- Project overview and requirement mapping.
- Assumptions and design decisions.
- Feature explanation.
- Reference to original full-stack source project.

## Assumptions and Design Decisions

- The app is evaluated as a mobile product, so this submission focuses on mobile-only code and behavior.
- Local persistence is selected to keep setup simple for reviewers and support offline usage.
- Some optional original full-stack integrations are intentionally excluded to keep the assessment scope clear.
- Biometric lock is configurable from settings instead of always enforced.

## Architecture Summary

- Language/Framework: Flutter + Dart
- State Management: BLoC/Cubit + Riverpod providers
- Persistence: Hive
- Charts/Visuals: Syncfusion Flutter Charts
- Folder style: feature-first with separated domain/data/presentation layers

## Android-Only Setup Instructions

### Prerequisites

- Flutter SDK installed and available in PATH
- Android Studio (SDK + platform tools)
- At least one Android emulator or physical Android device

### 1) Clone

```bash
git clone https://github.com/kalutm/zorvyn_finance_companion
cd finance_companion
```

### 2) Install dependencies

```bash
flutter pub get
```

### 3) Verify toolchain

```bash
flutter doctor
```

### 4) Run on Android

```bash
flutter devices
flutter run
```

## Main Feature Areas

- Transactions
- Accounts
- Categories
- Budgets
- Insights / Report & Analytics
- Settings (Theme + Biometric Lock Toggle + Load Demo Data)

## App Naming Note

For this assessment submission, the app is presented as **Finance Companion**.

## Contact / Submission Notes

- If needed, reviewers can compare this mobile-only submission with the original full-stack implementation:
	- https://github.com/kalutm/finance_tracker

