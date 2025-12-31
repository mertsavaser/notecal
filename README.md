# NoteCal

**A minimalist calorie tracking mobile application built with Flutter and Firebase.**

NoteCal helps users track their daily calorie intake and macronutrients through an intuitive, streamlined interface. The app focuses on simplicity and ease of use, allowing users to log meals quickly and monitor their nutritional progress over time.

## Overview

NoteCal is a cross-platform mobile application (iOS and Android) that enables users to:

- Search and log foods from a comprehensive database
- Track daily calorie consumption and macronutrient intake (protein, carbohydrates, fat)
- Organize meals by type (Breakfast, Lunch, Dinner) or create custom meal categories
- View weekly progress and nutritional trends
- Calculate personalized daily calorie targets based on user profile (TDEE)
- Maintain a complete nutritional history

The application uses Firebase for authentication, real-time data synchronization, and cloud storage, ensuring a seamless experience across devices.

## Key Features

### Food Logging
- **Food Search**: Real-time search through a Firestore-based food database with debounced queries
- **Meal Organization**: System meals (Breakfast, Lunch, Dinner) and custom meal creation
- **Macro Tracking**: Automatic calculation and display of calories, protein, carbohydrates, and fat per food item
- **Serving Size Control**: Adjustable serving amounts with unit selection (grams, ounces, etc.)

### Daily Tracking
- **Real-time Updates**: Live calorie and macro totals using Firestore streams
- **Progress Visualization**: Visual progress indicators for daily calorie goals
- **Daily Summary**: Automatic calculation of total daily intake across all meals

### Progress & Analytics
- **Weekly View**: Navigate through weeks to review historical data
- **Adherence Scoring**: Weekly score calculation based on calorie and macro adherence
- **History Tracking**: Access previous days' meal logs and summaries

### User Profile
- **Profile Setup**: Onboarding flow for new users with body metrics collection
- **TDEE Calculation**: Automatic calculation of Total Daily Energy Expenditure based on:
  - Weight, height, age, gender
  - Activity level (Sedentary to Athlete)
- **Macro Targets**: Automatic macro distribution (30% protein, 40% carbs, 30% fat) based on TDEE
- **Profile Management**: Edit profile information and recalculate targets

### Authentication
- **Multiple Providers**: Support for email/password, Google Sign-In, and Sign in with Apple
- **Secure Authentication**: Firebase Authentication with secure session management
- **Profile Completion**: Guided profile setup for new users

## Technical Stack

### Frontend
- **Flutter** (Dart SDK ^3.10.1)
- **Material Design 3**: Modern UI components and theming
- **State Management**: Flutter's built-in state management with StreamBuilder for real-time updates

### Backend & Services
- **Firebase Core**: Project initialization and configuration
- **Firebase Authentication**: User authentication and session management
- **Cloud Firestore**: NoSQL database for:
  - User profiles and preferences
  - Food database with searchable indexes
  - Daily meal logs and nutritional data
  - Real-time data synchronization
- **Google Sign-In**: OAuth integration for Google authentication
- **Sign in with Apple**: Apple ID authentication for iOS users

### Local Storage
- **SharedPreferences**: Onboarding completion status and local preferences

### Development Tools
- **Flutter Lints**: Code quality and best practices
- **Flutter Launcher Icons**: App icon generation

## Architecture

The application follows a service-oriented architecture with clear separation of concerns:

### Core Components
- **Services Layer**: Business logic and data operations
  - `MealService`: Manages meal creation, food logging, and daily summaries
  - `FirestoreFoodService`: Handles food database search and retrieval
  - `FirestoreHelper`: User profile management and validation
- **Screens Layer**: UI screens organized by feature
  - Authentication (login, signup, profile setup)
  - Home (daily meal tracking)
  - Progress (weekly analytics)
  - Profile (user settings and information)
- **Widgets Layer**: Reusable UI components
  - Food cards, input fields, macro displays, category pills
- **Core Layer**: Application initialization and routing
  - `RootWrapper`: Handles authentication state and onboarding flow
  - `AuthWrapper`: Manages authenticated user experience

### Data Structure

**Firestore Collections:**
```
users/
  {userId}/
    - Profile data (weight, height, age, gender, activityLevel, TDEE)
    days/
      {yyyy-MM-dd}/
        - Daily summary (totalCalories, totalProtein, totalCarbs, totalFat)
        meals/
          {mealId}/
            - Meal metadata (name, type, createdAt)
            foods/
              {foodId}/
                - Food data (name, calories, protein, carbs, fat, amount, unit)

foods/
  {foodId}/
    - Food database entries (name, name_lowercase, calories, protein, carbs, fat, serving_size, category)
```

### Real-time Updates

The application leverages Firestore's real-time capabilities:
- `StreamBuilder` widgets for live meal and food updates
- Automatic UI refresh when data changes
- Optimistic UI updates for better user experience

## Project Status

**Current Version**: 1.0.0

### Completed Features
- ✅ User authentication (email, Google, Apple)
- ✅ Food database search and logging
- ✅ Meal management (system and custom meals)
- ✅ Daily calorie and macro tracking
- ✅ Weekly progress view
- ✅ User profile with TDEE calculation
- ✅ Onboarding flow
- ✅ Real-time data synchronization

### Roadmap
- 🔄 App Store and Google Play Store release
- 📱 Enhanced offline support
- 📊 Advanced analytics and insights
- 🍽️ Meal templates and favorites
- 🔔 Reminder notifications
- 🌐 Multi-language support expansion

## Setup Instructions

### Prerequisites
- Flutter SDK (3.10.1 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for platform-specific builds)
- Firebase project with Firestore and Authentication enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd my_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   
   **Important**: Firebase configuration files are not committed to the repository for security reasons. You must add your own Firebase configuration files:
   
   - **Android**: Place `google-services.json` in `android/app/`
   - **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`
   
   These files can be downloaded from your Firebase Console under Project Settings.

4. **Firestore Setup**
   - Create a Firestore database in your Firebase project
   - Set up the following collections:
     - `users` (for user profiles)
     - `foods` (for the food database)
   - Create a composite index on `foods` collection:
     - Field: `name_lowercase` (Ascending)
     - This index is required for food search functionality

5. **Authentication Setup**
   - Enable Email/Password authentication in Firebase Console
   - Configure Google Sign-In (OAuth client IDs)
   - Configure Sign in with Apple (iOS only)

6. **Run the application**
   ```bash
   flutter run
   ```

### Environment Variables

No environment variables are required. All configuration is handled through Firebase configuration files (which are git-ignored).

## Folder Structure

```
lib/
├── bottom_sheets/          # Modal bottom sheets (food detail, add meal)
├── constants/              # App constants (colors, images, text styles)
├── core/                   # Core application logic
│   ├── auth_wrapper.dart
│   ├── firestore_helper.dart
│   ├── onboarding_helper.dart
│   └── root_wrapper.dart
├── routes/                 # Navigation routes
├── screens/                # Application screens
│   ├── auth/               # Authentication screens
│   ├── home/               # Home, progress, profile screens
│   └── onboarding/         # Onboarding flow
├── services/               # Business logic services
│   ├── firestore_food_service.dart
│   └── meal_service.dart
└── widgets/                # Reusable UI components

android/                    # Android platform files
ios/                        # iOS platform files
assets/                     # Images, videos, and other assets
test/                       # Unit and widget tests
```

## Screenshots

_Coming soon - Screenshots will be added after app store release._

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter and Dart style guidelines
- Write meaningful commit messages
- Add tests for new features when applicable
- Ensure all existing tests pass
- Update documentation as needed

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

**Author**: mertsavaser  
**GitHub**: [@mertsavaser](https://github.com/mertsavaser)

For questions, suggestions, or issues, please open an issue on the GitHub repository.
