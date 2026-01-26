import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'NoteCal'**
  String get appTitle;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Log your meals effortlessly'**
  String get onboardingTitle1;

  /// No description provided for @onboardingSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'Stay aware of what you eat with simple, fast meal tracking.'**
  String get onboardingSubtitle1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Know your daily intake'**
  String get onboardingTitle2;

  /// No description provided for @onboardingSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'See your calories clearly with clean, easy-to-read visuals.'**
  String get onboardingSubtitle2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Stay consistent'**
  String get onboardingTitle3;

  /// No description provided for @onboardingSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'Track progress and build healthier eating routines.'**
  String get onboardingSubtitle3;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Login to continue'**
  String get loginToContinue;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @appleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get appleSignIn;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signUpToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Sign up to get started'**
  String get signUpToGetStarted;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @noUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found with this email'**
  String get noUserFound;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmailAddress;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled'**
  String get accountDisabled;

  /// No description provided for @invalidEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidEmailOrPassword;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// No description provided for @thisEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get thisEmailAlreadyRegistered;

  /// No description provided for @emailPasswordNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Email/password accounts are not enabled'**
  String get emailPasswordNotEnabled;

  /// No description provided for @passwordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get passwordTooWeak;

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get accountCreatedSuccessfully;

  /// No description provided for @setUpYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setUpYourProfile;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself to calculate your BMR'**
  String get tellUsAboutYourself;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get lastNameRequired;

  /// No description provided for @ageRequired.
  ///
  /// In en, this message translates to:
  /// **'Age is required'**
  String get ageRequired;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @ageBetween11And99.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 11 and 99'**
  String get ageBetween11And99;

  /// No description provided for @heightRequired.
  ///
  /// In en, this message translates to:
  /// **'Height is required'**
  String get heightRequired;

  /// No description provided for @pleaseEnterValidHeight.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid height (cm)'**
  String get pleaseEnterValidHeight;

  /// No description provided for @weightRequired.
  ///
  /// In en, this message translates to:
  /// **'Weight is required'**
  String get weightRequired;

  /// No description provided for @pleaseEnterValidWeight.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid weight (kg)'**
  String get pleaseEnterValidWeight;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary (little or no exercise)'**
  String get sedentary;

  /// No description provided for @lightlyActive.
  ///
  /// In en, this message translates to:
  /// **'Lightly active (1–3 days/week)'**
  String get lightlyActive;

  /// No description provided for @moderatelyActive.
  ///
  /// In en, this message translates to:
  /// **'Moderately active (3–5 days/week)'**
  String get moderatelyActive;

  /// No description provided for @veryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active (6–7 days/week)'**
  String get veryActive;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete / super active'**
  String get athlete;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get snack;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @addMeal.
  ///
  /// In en, this message translates to:
  /// **'Add Meal'**
  String get addMeal;

  /// No description provided for @caloriesRemaining.
  ///
  /// In en, this message translates to:
  /// **'calories remaining'**
  String get caloriesRemaining;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @consumed.
  ///
  /// In en, this message translates to:
  /// **'Consumed'**
  String get consumed;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @cal.
  ///
  /// In en, this message translates to:
  /// **'cal'**
  String get cal;

  /// No description provided for @noMealsYet.
  ///
  /// In en, this message translates to:
  /// **'No meals yet'**
  String get noMealsYet;

  /// No description provided for @tapAddMealToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add Meal\" to get started'**
  String get tapAddMealToGetStarted;

  /// No description provided for @addFood.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get addFood;

  /// No description provided for @addYourFirstFood.
  ///
  /// In en, this message translates to:
  /// **'Add your first food'**
  String get addYourFirstFood;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @renameMeal.
  ///
  /// In en, this message translates to:
  /// **'Rename Meal'**
  String get renameMeal;

  /// No description provided for @enterMealName.
  ///
  /// In en, this message translates to:
  /// **'Enter meal name'**
  String get enterMealName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @mealNameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Meal name cannot be empty'**
  String get mealNameCannotBeEmpty;

  /// No description provided for @failedToRenameMeal.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename meal'**
  String get failedToRenameMeal;

  /// No description provided for @mealWithThisNameExists.
  ///
  /// In en, this message translates to:
  /// **'A meal with this name already exists'**
  String get mealWithThisNameExists;

  /// No description provided for @deleteMeal.
  ///
  /// In en, this message translates to:
  /// **'Delete Meal'**
  String get deleteMeal;

  /// No description provided for @deleteMealConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This meal contains {foodCount} food item{foodCount, plural, =0{} =1{} other{s}}. Are you sure you want to delete \"{mealName}\"?'**
  String deleteMealConfirmation(int foodCount, String mealName);

  /// No description provided for @deleteMealConfirmationNoFood.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{mealName}\"?'**
  String deleteMealConfirmationNoFood(String mealName);

  /// No description provided for @failedToDeleteMeal.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete meal'**
  String get failedToDeleteMeal;

  /// No description provided for @mealDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{mealName}\" deleted'**
  String mealDeleted(String mealName);

  /// No description provided for @errorSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Error signing out: {error}'**
  String errorSigningOut(String error);

  /// No description provided for @systemMeals.
  ///
  /// In en, this message translates to:
  /// **'System Meals'**
  String get systemMeals;

  /// No description provided for @customMeal.
  ///
  /// In en, this message translates to:
  /// **'Custom Meal'**
  String get customMeal;

  /// No description provided for @enterMealNameExample.
  ///
  /// In en, this message translates to:
  /// **'Enter meal name (e.g. \"Pre-workout\")'**
  String get enterMealNameExample;

  /// No description provided for @pleaseEnterMealName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a meal name'**
  String get pleaseEnterMealName;

  /// No description provided for @failedToCreateMeal.
  ///
  /// In en, this message translates to:
  /// **'Failed to create meal. Please try again.'**
  String get failedToCreateMeal;

  /// No description provided for @mealNameReserved.
  ///
  /// In en, this message translates to:
  /// **'This meal name is reserved. Please choose a different name.'**
  String get mealNameReserved;

  /// No description provided for @searchFood.
  ///
  /// In en, this message translates to:
  /// **'Search Food'**
  String get searchFood;

  /// No description provided for @searchFoods.
  ///
  /// In en, this message translates to:
  /// **'Search foods...'**
  String get searchFoods;

  /// No description provided for @startTypingToSearch.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search foods'**
  String get startTypingToSearch;

  /// No description provided for @noFoodsFound.
  ///
  /// In en, this message translates to:
  /// **'No foods found'**
  String get noFoodsFound;

  /// No description provided for @tryDifferentSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearchTerm;

  /// No description provided for @serving.
  ///
  /// In en, this message translates to:
  /// **'Serving'**
  String get serving;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @addToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add to Meal'**
  String get addToMeal;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @foodAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{foodName} added successfully'**
  String foodAddedSuccessfully(String foodName);

  /// No description provided for @failedToAddFood.
  ///
  /// In en, this message translates to:
  /// **'Failed to add food. Please try again.'**
  String get failedToAddFood;

  /// No description provided for @removeFood.
  ///
  /// In en, this message translates to:
  /// **'Remove Food'**
  String get removeFood;

  /// No description provided for @removeFoodConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{foodName}\" from this meal?'**
  String removeFoodConfirmation(String foodName);

  /// No description provided for @removeFromMeal.
  ///
  /// In en, this message translates to:
  /// **'Remove from Meal'**
  String get removeFromMeal;

  /// No description provided for @failedToUpdateFood.
  ///
  /// In en, this message translates to:
  /// **'Failed to update food item'**
  String get failedToUpdateFood;

  /// No description provided for @failedToRemoveFood.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove food item'**
  String get failedToRemoveFood;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @unknownFood.
  ///
  /// In en, this message translates to:
  /// **'Unknown Food'**
  String get unknownFood;

  /// No description provided for @bodyInformation.
  ///
  /// In en, this message translates to:
  /// **'Body Information'**
  String get bodyInformation;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @nutritionTargets.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Targets'**
  String get nutritionTargets;

  /// No description provided for @dailyCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily Calories'**
  String get dailyCalories;

  /// No description provided for @recalculateCaloriesToSeeTargets.
  ///
  /// In en, this message translates to:
  /// **'Recalculate calories to see targets'**
  String get recalculateCaloriesToSeeTargets;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @activityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity Level'**
  String get activityLevel;

  /// No description provided for @recalculateDailyCalories.
  ///
  /// In en, this message translates to:
  /// **'Recalculate Daily Calories'**
  String get recalculateDailyCalories;

  /// No description provided for @dailyCaloriesRecalculated.
  ///
  /// In en, this message translates to:
  /// **'Daily calories recalculated successfully'**
  String get dailyCaloriesRecalculated;

  /// No description provided for @weeklyScore.
  ///
  /// In en, this message translates to:
  /// **'Weekly Score'**
  String get weeklyScore;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @notLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Not logged yet'**
  String get notLoggedYet;

  /// No description provided for @noWeekDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No week data available'**
  String get noWeekDataAvailable;

  /// No description provided for @unableToCalculateWeeklyScore.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate weekly score'**
  String get unableToCalculateWeeklyScore;

  /// No description provided for @greatConsistency.
  ///
  /// In en, this message translates to:
  /// **'Great consistency this week'**
  String get greatConsistency;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'You\'re on track'**
  String get onTrack;

  /// No description provided for @makingProgress.
  ///
  /// In en, this message translates to:
  /// **'Making good progress'**
  String get makingProgress;

  /// No description provided for @freshStart.
  ///
  /// In en, this message translates to:
  /// **'Every day is a fresh start'**
  String get freshStart;

  /// No description provided for @noMealsLoggedForDay.
  ///
  /// In en, this message translates to:
  /// **'No meals logged for this day'**
  String get noMealsLoggedForDay;

  /// No description provided for @errorLoadingDailySummary.
  ///
  /// In en, this message translates to:
  /// **'Error loading daily summary'**
  String get errorLoadingDailySummary;

  /// No description provided for @errorLoadingMeals.
  ///
  /// In en, this message translates to:
  /// **'Error loading meals'**
  String get errorLoadingMeals;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed'**
  String get googleSignInFailed;

  /// No description provided for @googleSignInCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In canceled by user'**
  String get googleSignInCanceled;

  /// No description provided for @googleSignInInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In was interrupted. Please try again.'**
  String get googleSignInInterrupted;

  /// No description provided for @googleSignInConfigError.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In configuration error. Please ensure SHA-1 and SHA-256 certificates are added to Firebase Console. Get your SHA keys using: keytool -list -v -keystore android/app/debug.keystore'**
  String get googleSignInConfigError;

  /// No description provided for @accountExistsDifferentCredential.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email using a different sign-in method.'**
  String get accountExistsDifferentCredential;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Please try again.'**
  String get invalidCredentials;

  /// No description provided for @googleSignInNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is not enabled. Please contact support.'**
  String get googleSignInNotEnabled;

  /// No description provided for @userAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'User account not found.'**
  String get userAccountNotFound;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: {message}'**
  String authenticationFailed(String message);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @appleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In failed'**
  String get appleSignInFailed;

  /// No description provided for @appleSignInCanceled.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In was canceled'**
  String get appleSignInCanceled;

  /// No description provided for @appleSignInNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In is not available. Please check your device settings.'**
  String get appleSignInNotAvailable;

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile: {error}'**
  String errorSavingProfile(String error);

  /// No description provided for @authenticationError.
  ///
  /// In en, this message translates to:
  /// **'Authentication Error'**
  String get authenticationError;

  /// No description provided for @errorLoadingApp.
  ///
  /// In en, this message translates to:
  /// **'Error loading app'**
  String get errorLoadingApp;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @anErrorOccurredTurkish.
  ///
  /// In en, this message translates to:
  /// **'Bir hata oluştu'**
  String get anErrorOccurredTurkish;

  /// No description provided for @firebaseConfigError.
  ///
  /// In en, this message translates to:
  /// **'Firebase Yapılandırma Hatası'**
  String get firebaseConfigError;

  /// No description provided for @firebaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Firebase düzgün yapılandırılmamış.\n\nLütfen şunları kontrol edin:\n• iOS: ios/Runner/GoogleService-Info.plist dosyası mevcut mu?\n• Android: android/app/google-services.json dosyası mevcut mu?\n• Firebase Console\'dan doğru dosyaları indirdiniz mi?'**
  String get firebaseNotConfigured;

  /// No description provided for @errorDetail.
  ///
  /// In en, this message translates to:
  /// **'Hata Detayı:\n{error}'**
  String errorDetail(String error);

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @dailyTargets.
  ///
  /// In en, this message translates to:
  /// **'Daily Targets'**
  String get dailyTargets;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @bodyStats.
  ///
  /// In en, this message translates to:
  /// **'Body Stats'**
  String get bodyStats;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @signOutConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmationTitle;

  /// No description provided for @signOutConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmationMessage;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountConfirmationTitle;

  /// No description provided for @deleteAccountConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get deleteAccountConfirmationMessage;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeleted;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {error}'**
  String errorDeletingAccount(Object error);

  /// No description provided for @networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network timeout. Please try again.'**
  String get networkTimeout;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
