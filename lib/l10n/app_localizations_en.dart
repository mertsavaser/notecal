// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NoteCal';

  @override
  String get onboardingTitle1 => 'Log your meals effortlessly';

  @override
  String get onboardingSubtitle1 =>
      'Stay aware of what you eat with simple, fast meal tracking.';

  @override
  String get onboardingTitle2 => 'Know your daily intake';

  @override
  String get onboardingSubtitle2 =>
      'See your calories clearly with clean, easy-to-read visuals.';

  @override
  String get onboardingTitle3 => 'Stay consistent';

  @override
  String get onboardingSubtitle3 =>
      'Track progress and build healthier eating routines.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginToContinue => 'Login to continue';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get or => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get appleSignIn => 'Apple ile giriş';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signUpToGetStarted => 'Sign up to get started';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get noUserFound => 'No user found with this email';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String get invalidEmailAddress => 'Invalid email address';

  @override
  String get accountDisabled => 'This account has been disabled';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password';

  @override
  String get anErrorOccurred => 'An error occurred';

  @override
  String get thisEmailAlreadyRegistered => 'This email is already registered';

  @override
  String get emailPasswordNotEnabled =>
      'Email/password accounts are not enabled';

  @override
  String get passwordTooWeak => 'Password is too weak';

  @override
  String get accountCreatedSuccessfully => 'Account created successfully!';

  @override
  String get setUpYourProfile => 'Set up your profile';

  @override
  String get tellUsAboutYourself =>
      'Tell us about yourself to calculate your BMR';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get continueButton => 'Continue';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get lastNameRequired => 'Last name is required';

  @override
  String get ageRequired => 'Age is required';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get ageBetween11And99 => 'Age must be between 11 and 99';

  @override
  String get heightRequired => 'Height is required';

  @override
  String get pleaseEnterValidHeight => 'Please enter a valid height (cm)';

  @override
  String get weightRequired => 'Weight is required';

  @override
  String get pleaseEnterValidWeight => 'Please enter a valid weight (kg)';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get sedentary => 'Sedentary (little or no exercise)';

  @override
  String get lightlyActive => 'Lightly active (1–3 days/week)';

  @override
  String get moderatelyActive => 'Moderately active (3–5 days/week)';

  @override
  String get veryActive => 'Very active (6–7 days/week)';

  @override
  String get athlete => 'Athlete / super active';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get snack => 'Snack';

  @override
  String get home => 'Home';

  @override
  String get progress => 'Progress';

  @override
  String get profile => 'Profile';

  @override
  String get meals => 'Meals';

  @override
  String get addMeal => 'Add Meal';

  @override
  String get caloriesRemaining => 'calories remaining';

  @override
  String get target => 'Target';

  @override
  String get consumed => 'Consumed';

  @override
  String get remaining => 'Remaining';

  @override
  String get protein => 'Protein';

  @override
  String get carbs => 'Carbs';

  @override
  String get fat => 'Fat';

  @override
  String get cal => 'cal';

  @override
  String get noMealsYet => 'No meals yet';

  @override
  String get tapAddMealToGetStarted => 'Tap \"Add Meal\" to get started';

  @override
  String get addFood => 'Add food';

  @override
  String get addYourFirstFood => 'Add your first food';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get renameMeal => 'Rename Meal';

  @override
  String get enterMealName => 'Enter meal name';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get mealNameCannotBeEmpty => 'Meal name cannot be empty';

  @override
  String get failedToRenameMeal => 'Failed to rename meal';

  @override
  String get mealWithThisNameExists => 'A meal with this name already exists';

  @override
  String get deleteMeal => 'Delete Meal';

  @override
  String deleteMealConfirmation(int foodCount, String mealName) {
    String _temp0 = intl.Intl.pluralLogic(
      foodCount,
      locale: localeName,
      other: 's',
      one: '',
      zero: '',
    );
    return 'This meal contains $foodCount food item$_temp0. Are you sure you want to delete \"$mealName\"?';
  }

  @override
  String deleteMealConfirmationNoFood(String mealName) {
    return 'Are you sure you want to delete \"$mealName\"?';
  }

  @override
  String get failedToDeleteMeal => 'Failed to delete meal';

  @override
  String mealDeleted(String mealName) {
    return '\"$mealName\" deleted';
  }

  @override
  String errorSigningOut(String error) {
    return 'Error signing out: $error';
  }

  @override
  String get systemMeals => 'System Meals';

  @override
  String get customMeal => 'Custom Meal';

  @override
  String get enterMealNameExample => 'Enter meal name (e.g. \"Pre-workout\")';

  @override
  String get pleaseEnterMealName => 'Please enter a meal name';

  @override
  String get failedToCreateMeal => 'Failed to create meal. Please try again.';

  @override
  String get mealNameReserved =>
      'This meal name is reserved. Please choose a different name.';

  @override
  String get searchFood => 'Search Food';

  @override
  String get searchFoods => 'Search foods...';

  @override
  String get startTypingToSearch => 'Start typing to search foods';

  @override
  String get noFoodsFound => 'No foods found';

  @override
  String get tryDifferentSearchTerm => 'Try a different search term';

  @override
  String get serving => 'Serving';

  @override
  String get amount => 'Amount';

  @override
  String get addToMeal => 'Add to Meal';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String foodAddedSuccessfully(String foodName) {
    return '$foodName added successfully';
  }

  @override
  String get failedToAddFood => 'Failed to add food. Please try again.';

  @override
  String get removeFood => 'Remove Food';

  @override
  String removeFoodConfirmation(String foodName) {
    return 'Remove \"$foodName\" from this meal?';
  }

  @override
  String get removeFromMeal => 'Remove from Meal';

  @override
  String get failedToUpdateFood => 'Failed to update food item';

  @override
  String get failedToRemoveFood => 'Failed to remove food item';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get unknownFood => 'Unknown Food';

  @override
  String get bodyInformation => 'Body Information';

  @override
  String get edit => 'Edit';

  @override
  String get notSet => 'Not set';

  @override
  String get years => 'years';

  @override
  String get nutritionTargets => 'Nutrition Targets';

  @override
  String get dailyCalories => 'Daily Calories';

  @override
  String get recalculateCaloriesToSeeTargets =>
      'Recalculate calories to see targets';

  @override
  String get account => 'Account';

  @override
  String get notAvailable => 'Not available';

  @override
  String get signOut => 'Sign Out';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get activityLevel => 'Activity Level';

  @override
  String get recalculateDailyCalories => 'Recalculate Daily Calories';

  @override
  String get dailyCaloriesRecalculated =>
      'Daily calories recalculated successfully';

  @override
  String get weeklyScore => 'Weekly Score';

  @override
  String get thisWeek => 'This Week';

  @override
  String get today => 'Today';

  @override
  String get notLoggedYet => 'Not logged yet';

  @override
  String get noWeekDataAvailable => 'No week data available';

  @override
  String get unableToCalculateWeeklyScore => 'Unable to calculate weekly score';

  @override
  String get greatConsistency => 'Great consistency this week';

  @override
  String get onTrack => 'You\'re on track';

  @override
  String get makingProgress => 'Making good progress';

  @override
  String get freshStart => 'Every day is a fresh start';

  @override
  String get noMealsLoggedForDay => 'No meals logged for this day';

  @override
  String get errorLoadingDailySummary => 'Error loading daily summary';

  @override
  String get errorLoadingMeals => 'Error loading meals';

  @override
  String get googleSignInFailed => 'Google Sign-In failed';

  @override
  String get googleSignInCanceled => 'Google Sign-In canceled by user';

  @override
  String get googleSignInInterrupted =>
      'Google Sign-In was interrupted. Please try again.';

  @override
  String get googleSignInConfigError =>
      'Google Sign-In configuration error. Please ensure SHA-1 and SHA-256 certificates are added to Firebase Console. Get your SHA keys using: keytool -list -v -keystore android/app/debug.keystore';

  @override
  String get accountExistsDifferentCredential =>
      'An account already exists with this email using a different sign-in method.';

  @override
  String get invalidCredentials => 'Invalid credentials. Please try again.';

  @override
  String get googleSignInNotEnabled =>
      'Google Sign-In is not enabled. Please contact support.';

  @override
  String get userAccountNotFound => 'User account not found.';

  @override
  String authenticationFailed(String message) {
    return 'Authentication failed: $message';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String get appleSignInFailed => 'Apple Sign-In failed';

  @override
  String get appleSignInCanceled => 'Apple Sign-In was canceled';

  @override
  String get appleSignInNotAvailable =>
      'Apple Sign-In is not available. Please check your device settings.';

  @override
  String errorSavingProfile(String error) {
    return 'Error saving profile: $error';
  }

  @override
  String get authenticationError => 'Authentication Error';

  @override
  String get errorLoadingApp => 'Error loading app';

  @override
  String get retry => 'Retry';

  @override
  String get anErrorOccurredTurkish => 'Bir hata oluştu';

  @override
  String get firebaseConfigError => 'Firebase Yapılandırma Hatası';

  @override
  String get firebaseNotConfigured =>
      'Firebase düzgün yapılandırılmamış.\n\nLütfen şunları kontrol edin:\n• iOS: ios/Runner/GoogleService-Info.plist dosyası mevcut mu?\n• Android: android/app/google-services.json dosyası mevcut mu?\n• Firebase Console\'dan doğru dosyaları indirdiniz mi?';

  @override
  String errorDetail(String error) {
    return 'Hata Detayı:\n$error';
  }

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get profileTitle => 'Profile';

  @override
  String get dailyTargets => 'Daily Targets';

  @override
  String get calories => 'Calories';

  @override
  String get bodyStats => 'Body Stats';

  @override
  String get gender => 'Gender';

  @override
  String get signOutConfirmationTitle => 'Sign Out';

  @override
  String get signOutConfirmationMessage => 'Are you sure you want to sign out?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationMessage =>
      'Are you sure you want to delete your account? This action cannot be undone.';

  @override
  String get accountDeleted => 'Account deleted successfully';

  @override
  String errorDeletingAccount(Object error) {
    return 'Error deleting account: $error';
  }
}
