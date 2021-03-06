// -----------------------------------------------------------------------------
// Copyright 2011-2014 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "UserDefaultsUpdater.h"
#import "UIDeviceAdditions.h"
#import "../go/GoUtilities.h"
#import "../main/ApplicationDelegate.h"
#import "../player/GtpEngineProfile.h"
#import "../utility/NSStringAdditions.h"


// -----------------------------------------------------------------------------
/// @brief User defaults keys and values that are no longer active but that
/// are still used to perform upgrades.
// -----------------------------------------------------------------------------
//@{
NSString* boardInnerMarginPercentageKey = @"BoardInnerMarginPercentage";
NSString* crossHairPointDistanceFromFingerKey = @"CrossHairPointDistanceFromFinger";
NSString* blackPlayerKey = @"BlackPlayer";
NSString* whitePlayerKey = @"WhitePlayer";
NSString* placeStoneUnderFingerKey = @"PlaceStoneUnderFinger";
NSString* displayMoveNumbersKey = @"DisplayMoveNumbers";
NSString* boardPositionLastViewedKey = @"BoardPositionLastViewed";
NSString* boardOuterMarginPercentageKey = @"BoardOuterMarginPercentage";
const float stoneDistanceFromFingertipMaximum = 4.0;
const float maximumZoomScaleDefault = 3.0;
NSString* playViewKey = @"PlayView";
NSString* backgroundColorKey = @"BackgroundColor";
NSString* boardColorKey = @"BoardColor";
NSString* lineColorKey = @"LineColor";
NSString* boundingLineWidthKey = @"BoundingLineWidth";
NSString* normalLineWidthKey = @"NormalLineWidth";
NSString* starPointColorKey = @"StarPointColor";
NSString* starPointRadiusKey = @"StarPointRadius";
NSString* stoneRadiusPercentageKey = @"StoneRadiusPercentage";
NSString* crossHairColorKey = @"CrossHairColor";
NSString* alphaTerritoryColorBlackKey = @"AlphaTerritoryColorBlack";
NSString* alphaTerritoryColorWhiteKey = @"AlphaTerritoryColorWhite";
NSString* deadStoneSymbolColorKey = @"DeadStoneSymbolColor";
NSString* deadStoneSymbolPercentageKey = @"DeadStoneSymbolPercentage";
NSString* inconsistentTerritoryDotSymbolColorKey = @"InconsistentTerritoryDotSymbolColor";
NSString* inconsistentTerritoryDotSymbolPercentageKey = @"InconsistentTerritoryDotSymbolPercentage";
NSString* inconsistentTerritoryFillColorKey = @"InconsistentTerritoryFillColor";
NSString* inconsistentTerritoryFillColorAlphaKey = @"InconsistentTerritoryFillColorAlpha";
NSString* blackSekiSymbolColorKey = @"BlackSekiSymbolColor";
NSString* whiteSekiSymbolColorKey = @"WhiteSekiSymbolColor";
NSString* maximumZoomScaleKey = @"MaximumZoomScale";
NSString* selectedTabIndexKey = @"SelectedTabIndex";
//@}


@implementation UserDefaultsUpdater

// -----------------------------------------------------------------------------
/// @brief Performs all the required upgrades to the user defaults data to reach
/// the data format that matches the one present in the registration domain
/// defaults dictionary @a registrationDomainDefaults.
///
/// Returns the number of upgrades performed. Probably the most interesting
/// thing about this number is whether it is zero (no upgrades were performed)
/// or non-zero (some upgrades were performed). The actual numeric value
/// probably has a low information value.
///
/// @note Since it is possible to have gaps in the version numbering scheme
/// (see class documentation for details), it is not possible to infer from the
/// number of upgrades that is returned which format the user defaults were in
/// when the upgrade process started its work.
///
/// @retval 0 No upgrades were performed.
/// @retval >0 The number of upgrades that were performed.
/// @retval -1 A downgrade was performed.
///
/// Raises an @e NSInternalInconsistencyException if it is found that
/// @a registrationDomainDefaults have already been registered in the user
/// defaults system.
// -----------------------------------------------------------------------------
+ (int) upgradeToRegistrationDomainDefaults:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Perform the check whether registration domain defaults are already
  // registered only once. The reason for this is that during unit tests this
  // method may be invoked multiple times, but from the 2nd time onwards the
  // registration domain defaults will always be present.
  static int numberOfTimesThisMethodHasBeenInvoked = 0;
  ++numberOfTimesThisMethodHasBeenInvoked;
  if (1 == numberOfTimesThisMethodHasBeenInvoked)
  {
    id registrationDomainVersionInUserDefaults = [userDefaults objectForKey:userDefaultsVersionRegistrationDomainKey];
    if (registrationDomainVersionInUserDefaults)
    {
      NSString* errorMessage = @"UserDefaultsUpdater: Aborting upgrade, registration domain defaults are already registered";
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSInternalInconsistencyException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }

  int registrationDomainVersion = [[registrationDomainDefaults valueForKey:userDefaultsVersionRegistrationDomainKey] intValue];
  int applicationDomainVersion = [[userDefaults valueForKey:userDefaultsVersionApplicationDomainKey] intValue];
  int numberOfUpgradesPerformed = 0;  // aka the return value :-)
  if (applicationDomainVersion == registrationDomainVersion)
  {
    // nothing to do
  }
  else if (applicationDomainVersion > registrationDomainVersion)
  {
    DDLogWarn(@"UserDefaultsUpdater performs DOWNGRADE operation. Downgrade to target version = %d, current version = %d",
              registrationDomainVersion,
              applicationDomainVersion);
    // TODO perform downgrade
    numberOfUpgradesPerformed = -1;
  }
  else
  {
    while (applicationDomainVersion < registrationDomainVersion)
    {
      // Incrementally perform upgrades. We allow for gaps in the user defaults
      // versioning scheme.
      ++applicationDomainVersion;
      NSString* upgradeMethodName = [NSString stringWithFormat:@"upgradeToVersion%d:", applicationDomainVersion];
      SEL upgradeSelector = NSSelectorFromString(upgradeMethodName);
      if ([[UserDefaultsUpdater class] respondsToSelector:upgradeSelector])
      {
        DDLogInfo(@"UserDefaultsUpdater performs incremental upgrade to version = %d. Final target version = %d",
                  applicationDomainVersion,
                  registrationDomainVersion);
        // TODO How do we learn of success/failure of upgradeSelector, and how
        // do we react to failure?
        [[UserDefaultsUpdater class] performSelector:upgradeSelector withObject:registrationDomainDefaults];
        ++numberOfUpgradesPerformed;
        // Update the application domain version number
        [userDefaults setValue:[NSNumber numberWithInt:applicationDomainVersion]
                        forKey:userDefaultsVersionApplicationDomainKey];
      }
    }
  }
  if ([ApplicationDelegate sharedDelegate].writeUserDefaultsEnabled)
    [userDefaults synchronize];

  // Perform final check if the cumulative effect of all upgrades had the
  // desired effect.
  int realApplicationDomainVersion = [[userDefaults valueForKey:userDefaultsVersionApplicationDomainKey] intValue];
  if (realApplicationDomainVersion != registrationDomainVersion)
  {
    DDLogError(@"UserDefaultsUpdater failed! Current version after upgrades = %d, but should be %d",
              realApplicationDomainVersion,
              registrationDomainVersion);
    // TODO: Display an alert that notifies the user of the problem. The alert
    // should probably recommend a re-install. Also decide whether to allow the
    // user to continue, or to gracefully shutdown the application.
  }

  return numberOfUpgradesPerformed;
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 1.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion1:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    // No longer used, inner margin is now calculated depending on the board size
    [playViewDictionaryUpgrade removeObjectForKey:boardInnerMarginPercentageKey];
    // No longer used, distance is now calculated dynamically by PlayView
    [playViewDictionaryUpgrade removeObjectForKey:crossHairPointDistanceFromFingerKey];
    // New user preference
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithBool:NO] forKey:placeStoneUnderFingerKey];
    [userDefaults setObject:playViewDictionaryUpgrade forKey:playViewKey];
  }

  // Remove all user-defined players. The registration domain defaults nicely
  // demonstrate how players and GTP engine profiles can be combined, and it's
  // too complicated to upgrade user-defined players and still show useful
  // combinations.
  [userDefaults removeObjectForKey:playerListKey];

  // Remove all scoring user defaults. Too many changes in this dictionary,
  // and only 2 beta-testers are affected by the loss of 2 keys.
  [userDefaults removeObjectForKey:scoringKey];
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 2.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion2:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // The previous app version had a bug that might have allowed the user to
  // select a handicap for new games that was greater than the maximum handicap
  // allowed by certain small board sizes. If the illegal value managed to get
  // into the user defaults sysem we need to fix it here.
  id newGameDictionary = [userDefaults objectForKey:newGameKey];
  if (newGameDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* newGameDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:newGameDictionary];
    // This user defaults format still uses an index-based board size
    // -> convert to natural board size just for executing code, but DON'T
    //    convert value in the user defaults: this is done by the next
    //    incremental upgrade
    int indexBasedBoardSize = [[newGameDictionaryUpgrade valueForKey:boardSizeKey] intValue];
    enum GoBoardSize naturalBoardSize = GoBoardSizeMin + indexBasedBoardSize * 2;
    int handicap = [[newGameDictionaryUpgrade valueForKey:handicapKey] intValue];
    int maximumHandicap = [GoUtilities maximumHandicapForBoardSize:naturalBoardSize];
    if (handicap > maximumHandicap)
    {
      [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:maximumHandicap] forKey:handicapKey];
      [userDefaults setObject:newGameDictionaryUpgrade forKey:newGameKey];
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 3.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion3:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Numeric values for enumerated board sizes now correspond to natural board
  // sizes (e.g. the numeric value for BoardSize9 is now 9), whereas previously
  // numeric values for enumerated board sizes simply started with 0 and
  // monotonically increased by 1 per board size (e.g. the numeric value for
  // BoardSize7 was 0, for BoardSize9 it was 1, and so on). Here we need to
  // convert from the old-style to the new-style board size.
  id newGameDictionary = [userDefaults objectForKey:newGameKey];
  if (newGameDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* newGameDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:newGameDictionary];
    int indexBasedBoardSize = [[newGameDictionaryUpgrade valueForKey:boardSizeKey] intValue];
    int naturalBoardSize = GoBoardSizeMin + indexBasedBoardSize * 2;
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:naturalBoardSize] forKey:boardSizeKey];
    [userDefaults setObject:newGameDictionaryUpgrade forKey:newGameKey];
  }

  // A number of keys now exist only as device-specific variants so that we can
  // have different factory settings for different devices. We need to add
  // those device-specific keys to the PlayView dictionary, while retaining
  // the values that were previously stored under the key's base name.
  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    NSMutableDictionary* playViewDictionaryRegistrationDomain = [registrationDomainDefaults objectForKey:playViewKey];

    NSArray* keysWithoutDeviceSuffix = [NSArray arrayWithObjects:boundingLineWidthKey, starPointRadiusKey, placeStoneUnderFingerKey, nil];
    for (NSString* keyWithoutDeviceSuffix in keysWithoutDeviceSuffix)
    {
      NSString* upgradeDeviceSuffix;
      if ([keyWithoutDeviceSuffix isEqualToString:placeStoneUnderFingerKey])
      {
        // This user default can be changed by the user, so we preserve the
        // current value for the current device.
        upgradeDeviceSuffix = [UIDevice currentDeviceSuffix];
      }
      else
      {
        // These user defaults cannot be changed by the user, so we discard
        // their current values and instead take the values from the
        // registration domain defaults. For iPad users this will result in a
        // change because we are introducing new iPad-specific values in this
        // release.
        upgradeDeviceSuffix = nil;
      }
      [UserDefaultsUpdater upgradeDictionary:playViewDictionaryUpgrade
                                      forKey:keyWithoutDeviceSuffix
                         upgradeDeviceSuffix:upgradeDeviceSuffix
                  registrationDomainDefaults:playViewDictionaryRegistrationDomain];
    }

    [userDefaults setObject:playViewDictionaryUpgrade forKey:playViewKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 4.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion4:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Every GTP engine profile now has a number of additional keys
  id profileListArray = [userDefaults objectForKey:gtpEngineProfileListKey];
  if (profileListArray)  // is nil if the key is not present
  {
    NSMutableArray* profileListArrayUpgrade = [NSMutableArray array];
    for (NSDictionary* profileDictionary in profileListArray)
    {
      NSMutableDictionary* profileDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:profileDictionary];
      [profileDictionaryUpgrade setValue:[NSNumber numberWithUnsignedInt:fuegoMaxPonderTimeDefault] forKey:fuegoMaxPonderTimeKey];
      [profileDictionaryUpgrade setValue:[NSNumber numberWithUnsignedInt:fuegoMaxThinkingTimeDefault] forKey:fuegoMaxThinkingTimeKey];
      [profileDictionaryUpgrade setValue:[NSNumber numberWithUnsignedLongLong:fuegoMaxGamesDefault] forKey:fuegoMaxGamesKey];
      [profileListArrayUpgrade addObject:profileDictionaryUpgrade];
    }
    [userDefaults setObject:profileListArrayUpgrade forKey:gtpEngineProfileListKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 5.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion5:(NSDictionary*)registrationDomainDefaults
{
  // New top-level key
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setValue:[NSNumber numberWithBool:NO] forKey:loggingEnabledKey];

  // Add new dictionary with board position settings.
  //
  // Note: Although it would be much easier to do nothing in this upgrade and
  // simply let the application pick up the settings from the registration
  // domain defaults, doing so has the potential to make future upgrades more
  // complicated (e.g. a future upgrade inserting a new board position settings
  // key would first have to check if the dictionary is present). It is
  // therefore better not to postpone this work and just do what we need to do
  // right here where it belongs to the correct format version.
  NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:[NSNumber numberWithBool:discardFutureMovesAlertDefault] forKey:discardFutureMovesAlertKey];
  [dictionary setValue:[NSNumber numberWithInt:-1] forKey:boardPositionLastViewedKey];
  [userDefaults setObject:dictionary forKey:boardPositionKey];

  // Add new keys to "PlayView" dictionary
  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    // This key is new
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithInt:ScoreInfoType] forKey:infoTypeLastSelectedKey];
    // This key now has device-specific values
    [UserDefaultsUpdater upgradeDictionary:playViewDictionaryUpgrade
                                    forKey:boardOuterMarginPercentageKey
                       upgradeDeviceSuffix:nil
                registrationDomainDefaults:[registrationDomainDefaults objectForKey:playViewKey]];
    // placeStoneUnderFingerKey is replaced by stoneDistanceFromFingertip. The
    // original boolean value is converted into a corresponding float value.
    float stoneDistanceFromFingertip;
    bool placeStoneUnderFinger = [[playViewDictionary valueForKey:[placeStoneUnderFingerKey stringByAppendingDeviceSuffix]] boolValue];
    if (placeStoneUnderFinger)
      stoneDistanceFromFingertip = 0;
    else
      stoneDistanceFromFingertip = stoneDistanceFromFingertipDefault;
    [playViewDictionaryUpgrade removeObjectForKey:[placeStoneUnderFingerKey stringByAppendingDeviceSuffix]];
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithFloat:stoneDistanceFromFingertip] forKey:[stoneDistanceFromFingertipKey stringByAppendingDeviceSuffix]];

    [userDefaults setObject:playViewDictionaryUpgrade forKey:playViewKey];
  }

  // Add new keys to / remove unused key from "NewGame" dictionary
  id newGameDictionary = [userDefaults objectForKey:newGameKey];
  if (newGameDictionary)  // is nil if the key is not present
  {
    NSString* defaultHumanPlayerUUID = @"F1017CAF-BCF5-406F-AC4C-5B4F794C006C";
    NSString* defaultComputerPlayerUUID = @"766CDA23-0C58-480B-A8B5-1F34BDA41677";
    NSMutableDictionary* newGameDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:newGameDictionary];
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:gDefaultGameType] forKey:gameTypeKey];
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:gDefaultGameType] forKey:gameTypeLastSelectedKey];
    [newGameDictionaryUpgrade setValue:defaultHumanPlayerUUID forKey:humanPlayerKey];
    [newGameDictionaryUpgrade setValue:defaultComputerPlayerUUID forKey:computerPlayerKey];
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithBool:gDefaultComputerPlaysWhite] forKey:computerPlaysWhiteKey];
    [newGameDictionaryUpgrade setValue:defaultHumanPlayerUUID forKey:humanBlackPlayerKey];
    [newGameDictionaryUpgrade setValue:defaultHumanPlayerUUID forKey:humanWhitePlayerKey];
    [newGameDictionaryUpgrade setValue:defaultComputerPlayerUUID forKey:computerPlayerSelfPlayKey];
    [newGameDictionaryUpgrade removeObjectForKey:blackPlayerKey];
    [newGameDictionaryUpgrade removeObjectForKey:whitePlayerKey];
    [userDefaults setObject:newGameDictionaryUpgrade forKey:newGameKey];
  }

  // Add new key to "Scoring" dictionary
  id scoringDictionary = [userDefaults objectForKey:scoringKey];
  if (scoringDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* scoringDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:scoringDictionary];
    [scoringDictionaryUpgrade setValue:[NSNumber numberWithBool:true] forKey:scoreWhenGameEndsKey];
    [userDefaults setObject:scoringDictionaryUpgrade forKey:scoringKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 6.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion6:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Add new keys to / change existing keys in "PlayView" dictionary
  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    // This key is new
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithFloat:maximumZoomScaleDefault] forKey:maximumZoomScaleKey];
    // Replace "DisplayMoveNumbers" key with "MoveNumbersPercentage"
    [playViewDictionaryUpgrade removeObjectForKey:displayMoveNumbersKey];
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithFloat:moveNumbersPercentageDefault] forKey:moveNumbersPercentageKey];
    // Remove unused device-specific key
    for (NSString* deviceSuffix in [UIDevice deviceSuffixes])
    {
      NSString* keyWithDeviceSuffix = [boardOuterMarginPercentageKey stringByAppendingString:deviceSuffix];
      [playViewDictionaryUpgrade removeObjectForKey:keyWithDeviceSuffix];
    }
    // These keys change their value: The value they previously had
    // (between 0 and stoneDistanceFromFingertipMaximum) must be transformed
    // into a percentage (stoneDistanceFromFingertipMaximum = 100%). Because of
    // the new semantics of the user preference, we don't attempt a linear
    // conversion.
    for (NSString* deviceSuffix in [UIDevice deviceSuffixes])
    {
      NSString* keyWithDeviceSuffix = [stoneDistanceFromFingertipKey stringByAppendingString:deviceSuffix];
      float stoneDistanceFromFingertip = [[playViewDictionaryUpgrade valueForKey:keyWithDeviceSuffix] floatValue];
      if (stoneDistanceFromFingertip > 0)
        stoneDistanceFromFingertip = 1.0f;
      [playViewDictionaryUpgrade setValue:[NSNumber numberWithFloat:stoneDistanceFromFingertip] forKey:keyWithDeviceSuffix];
    }
    [userDefaults setObject:playViewDictionaryUpgrade forKey:playViewKey];
  }

  // Remove unused key from "BoardPosition" dictionary
  id boardPositionDictionary = [userDefaults objectForKey:boardPositionKey];
  if (boardPositionDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* boardPositionDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:boardPositionDictionary];
    [boardPositionDictionaryUpgrade removeObjectForKey:boardPositionLastViewedKey];
    [userDefaults setObject:boardPositionDictionaryUpgrade forKey:boardPositionKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 7.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion7:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Every GTP engine profile now has a number of additional keys
  id profileListArray = [userDefaults objectForKey:gtpEngineProfileListKey];
  if (profileListArray)  // is nil if the key is not present
  {
    NSMutableArray* profileListArrayUpgrade = [NSMutableArray array];
    for (NSDictionary* profileDictionary in profileListArray)
    {
      NSMutableDictionary* profileDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:profileDictionary];
      [profileDictionaryUpgrade setValue:[NSNumber numberWithBool:autoSelectFuegoResignMinGamesDefault] forKey:autoSelectFuegoResignMinGamesKey];
      unsigned long long fuegoResignMinGames;
      if (autoSelectFuegoResignMinGamesDefault)
      {
        unsigned long long fuegoMaxGames  = [[profileDictionaryUpgrade valueForKey:fuegoMaxGamesKey] unsignedLongLongValue];
        fuegoResignMinGames = [GtpEngineProfile fuegoResignMinGamesForMaxGames:fuegoMaxGames];
      }
      else
      {
        fuegoResignMinGames = fuegoResignMinGamesDefault;
      }
      [profileDictionaryUpgrade setValue:[NSNumber numberWithUnsignedLongLong:fuegoResignMinGames] forKey:fuegoResignMinGamesKey];
      NSMutableArray* fuegoResignThreshold = [NSMutableArray array];
      for (int arrayIndex = 0; arrayIndex < arraySizeFuegoResignThresholdDefault; ++arrayIndex)
      {
        NSNumber* resignThresholdDefault = [NSNumber numberWithInt:fuegoResignThresholdDefault[arrayIndex]];
        [fuegoResignThreshold addObject:resignThresholdDefault];
      }
      [profileDictionaryUpgrade setValue:fuegoResignThreshold forKey:fuegoResignThresholdKey];
      [profileListArrayUpgrade addObject:profileDictionaryUpgrade];
    }
    [userDefaults setObject:profileListArrayUpgrade forKey:gtpEngineProfileListKey];
  }

  // Add new key to "BoardPosition" dictionary
  id boardPositionDictionary = [userDefaults objectForKey:boardPositionKey];
  if (boardPositionDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* boardPositionDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:boardPositionDictionary];
    [boardPositionDictionaryUpgrade setValue:[NSNumber numberWithBool:markNextMoveDefault] forKey:markNextMoveKey];
    [userDefaults setObject:boardPositionDictionaryUpgrade forKey:boardPositionKey];
  }

  // New keys for tab bar controller appearance are top-level, so there is no
  // need to add values for them, they will be picked from the registration
  // domain defaults.
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 8.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion8:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Add new key to "PlayView" dictionary
  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    NSMutableDictionary* playViewDictionaryRegistrationDomain = [registrationDomainDefaults objectForKey:playViewKey];
    [playViewDictionaryUpgrade setValue:[NSNumber numberWithBool:displayPlayerInfluenceDefault] forKey:displayPlayerInfluenceKey];
    // Here we preserve the "maximum zoom scale" user default
    [UserDefaultsUpdater upgradeDictionary:playViewDictionaryUpgrade
                                    forKey:maximumZoomScaleKey
                       upgradeDeviceSuffix:[UIDevice currentDeviceSuffix]
                registrationDomainDefaults:playViewDictionaryRegistrationDomain];
    NSString* maximumZoomScaleKeyWithDeviceSuffix = [maximumZoomScaleKey stringByAppendingDeviceSuffix];
    float maximumZoomScaleUser = [[playViewDictionaryUpgrade valueForKey:maximumZoomScaleKeyWithDeviceSuffix] floatValue];
    float maximumZoomScaleRegistrationDomain = [[playViewDictionaryRegistrationDomain valueForKey:maximumZoomScaleKeyWithDeviceSuffix] floatValue];
    // Here we discard the user default if it is too high. It *will* be too high
    // if the user has never touched the preference.
    if (maximumZoomScaleUser > maximumZoomScaleRegistrationDomain)
      [playViewDictionaryUpgrade setValue:[NSNumber numberWithFloat:maximumZoomScaleRegistrationDomain] forKey:maximumZoomScaleKeyWithDeviceSuffix];

    [userDefaults setObject:playViewDictionaryUpgrade forKey:playViewKey];
  }

  // Add new key to "NewGame" dictionary
  id newGameDictionary = [userDefaults objectForKey:newGameKey];
  if (newGameDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* newGameDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:newGameDictionary];
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:GoKoRuleSimple] forKey:koRuleKey];
    [newGameDictionaryUpgrade setValue:[NSNumber numberWithInt:GoScoringSystemAreaScoring] forKey:scoringSystemKey];
    // We are switching the default scoring system from territory to area
    // scoring, so if the user still has the default komi for territory scoring,
    // we switch komi as well
    double komi = [[newGameDictionaryUpgrade valueForKey:komiKey] doubleValue];
    if (gDefaultKomiTerritoryScoring == komi)
      [newGameDictionaryUpgrade setValue:[NSNumber numberWithDouble:gDefaultKomiAreaScoring] forKey:komiKey];
    [userDefaults setObject:newGameDictionaryUpgrade forKey:newGameKey];
  }

  // Add new key to "Scoring" dictionary
  id scoringDictionary = [userDefaults objectForKey:scoringKey];
  if (scoringDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* scoringDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:scoringDictionary];
    [scoringDictionaryUpgrade setValue:[NSNumber numberWithInt:GoScoreMarkModeDead] forKey:scoreMarkModeKey];
    id scoringDictionaryRegistrationDefaults = [registrationDomainDefaults objectForKey:scoringKey];
    NSString* blackSekiSymbolColorString = [scoringDictionaryRegistrationDefaults valueForKey:blackSekiSymbolColorKey];
    if (! blackSekiSymbolColorString)
      blackSekiSymbolColorString = @"ff0000";
    [scoringDictionaryUpgrade setValue:blackSekiSymbolColorString forKey:blackSekiSymbolColorKey];
    NSString* whiteSekiSymbolColorString = [scoringDictionaryRegistrationDefaults valueForKey:whiteSekiSymbolColorKey];
    if (! whiteSekiSymbolColorString)
      whiteSekiSymbolColorString = @"ff0000";
    [scoringDictionaryUpgrade setValue:whiteSekiSymbolColorString forKey:whiteSekiSymbolColorKey];
    [userDefaults setObject:scoringDictionaryUpgrade forKey:scoringKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 9.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion9:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  // Remove obsolete keys from "PlayView" dictionary, and rename "PlayView"
  // to "BoardView" dictionary
  id playViewDictionary = [userDefaults objectForKey:playViewKey];
  if (playViewDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* playViewDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:playViewDictionary];
    [playViewDictionaryUpgrade removeObjectForKey:backgroundColorKey];
    [playViewDictionaryUpgrade removeObjectForKey:boardColorKey];
    [playViewDictionaryUpgrade removeObjectForKey:lineColorKey];
    [UserDefaultsUpdater removeDeviceSpecificKeysForDeviceAgnosticKey:boundingLineWidthKey fromDictionary:playViewDictionaryUpgrade];
    [playViewDictionaryUpgrade removeObjectForKey:normalLineWidthKey];
    [playViewDictionaryUpgrade removeObjectForKey:starPointColorKey];
    [UserDefaultsUpdater removeDeviceSpecificKeysForDeviceAgnosticKey:starPointRadiusKey fromDictionary:playViewDictionaryUpgrade];
    [playViewDictionaryUpgrade removeObjectForKey:stoneRadiusPercentageKey];
    [playViewDictionaryUpgrade removeObjectForKey:crossHairColorKey];
    [UserDefaultsUpdater removeDeviceSpecificKeysForDeviceAgnosticKey:maximumZoomScaleKey fromDictionary:playViewDictionaryUpgrade];
    [userDefaults setObject:playViewDictionaryUpgrade forKey:boardViewKey];
  }

  // Remove obsolete keys from "Scoring" dictionary
  id scoringDictionary = [userDefaults objectForKey:scoringKey];
  if (scoringDictionary)  // is nil if the key is not present
  {
    NSMutableDictionary* scoringDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:scoringDictionary];
    [scoringDictionaryUpgrade removeObjectForKey:alphaTerritoryColorBlackKey];
    [scoringDictionaryUpgrade removeObjectForKey:alphaTerritoryColorWhiteKey];
    [scoringDictionaryUpgrade removeObjectForKey:deadStoneSymbolColorKey];
    [scoringDictionaryUpgrade removeObjectForKey:deadStoneSymbolPercentageKey];
    [scoringDictionaryUpgrade removeObjectForKey:inconsistentTerritoryDotSymbolColorKey];
    [scoringDictionaryUpgrade removeObjectForKey:inconsistentTerritoryDotSymbolPercentageKey];
    [scoringDictionaryUpgrade removeObjectForKey:inconsistentTerritoryFillColorKey];
    [scoringDictionaryUpgrade removeObjectForKey:inconsistentTerritoryFillColorAlphaKey];
    [scoringDictionaryUpgrade removeObjectForKey:blackSekiSymbolColorKey];
    [scoringDictionaryUpgrade removeObjectForKey:whiteSekiSymbolColorKey];
    [userDefaults setObject:scoringDictionaryUpgrade forKey:scoringKey];
  }

  id profileListArray = [userDefaults objectForKey:gtpEngineProfileListKey];
  if (profileListArray)  // is nil if the key is not present
  {
    NSMutableArray* profileListArrayUpgrade = [NSMutableArray array];
    for (NSDictionary* profileDictionary in profileListArray)
    {
      NSMutableDictionary* profileDictionaryUpgrade = [NSMutableDictionary dictionaryWithDictionary:profileDictionary];
      NSString* uuid = [profileDictionaryUpgrade valueForKey:gtpEngineProfileUUIDKey];
      if ([uuid isEqualToString:@"1051CE0D-D8BA-405C-A93D-7AA140683D11"])
      {
        NSString* name = [profileDictionaryUpgrade valueForKey:gtpEngineProfileNameKey];
        // If the profile name is the same as the one we deployed, we assume
        // that the user did not change any values and that we can update name
        // and description
        if ([name isEqualToString:@"iPhone 4S"])
        {
          [profileDictionaryUpgrade setValue:@"Strong" forKey:gtpEngineProfileNameKey];
          [profileDictionaryUpgrade setValue:@"This profile uses maximum playing strength, doubles the memory used by the default profile, and makes use of a second processor core." forKey:gtpEngineProfileDescriptionKey];
        }
      }
      [profileListArrayUpgrade addObject:profileDictionaryUpgrade];
    }
    [userDefaults setObject:profileListArrayUpgrade forKey:gtpEngineProfileListKey];
  }
}

// -----------------------------------------------------------------------------
/// @brief Performs the incremental upgrade to the user defaults format
/// version 10.
// -----------------------------------------------------------------------------
+ (void) upgradeToVersion10:(NSDictionary*)registrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  // Just remove the value, we don't bother converting to the new key
  // "VisibleUIArea"
  [userDefaults removeObjectForKey:selectedTabIndexKey];
}

// -----------------------------------------------------------------------------
/// @brief Upgrades @a dictionary so that after the upgrade it contains
/// device-specific keys that match the device-agnostic @a key for all
/// supported devices.
///
/// If @a dictionary contains a value for the device-agnostic @a key, that value
/// will be preserved under a new device-specific key that is formed by tacking
/// @a upgradeDeviceSuffix on to @a key. If @a upgradeDeviceSuffix is nil, the
/// device-agnostic value will be discarded.
///
/// The values for the other device-specific keys are taken from
/// @a registrationDomainDefaults, unless @a dictionary already contains a value
/// for a device-specific key, in which case that value is preserved.
///
/// @note @a registrationDomainDefaults must be a sub-dictionary that
/// corresponds to @a dictionary, @e not the entire registration domain defaults
/// dictionary.
///
/// @note This method was implemented with the goal in mind that it can be
/// reused if 1) in the future more keys become device-specific, and 2) more
/// devices become supported.
// -----------------------------------------------------------------------------
+ (void) upgradeDictionary:(NSMutableDictionary*)dictionary forKey:(NSString*)key upgradeDeviceSuffix:(NSString*)upgradeDeviceSuffix registrationDomainDefaults:(NSDictionary*)registrationDomainDefaults
{
  id valueForKeyWithoutDeviceSuffix = [dictionary objectForKey:key];
  if (valueForKeyWithoutDeviceSuffix)
  {
    [dictionary removeObjectForKey:key];
    if (nil != upgradeDeviceSuffix)
    {
      NSString* keyWithUpgradeDeviceSuffix = [key stringByAppendingString:upgradeDeviceSuffix];
      [dictionary setValue:valueForKeyWithoutDeviceSuffix forKey:keyWithUpgradeDeviceSuffix];
    }
  }

  for (NSString* deviceSuffix in [UIDevice deviceSuffixes])
  {
    NSString* keyWithDeviceSuffix = [key stringByAppendingString:deviceSuffix];
    id valueForKeyWithDeviceSuffix = [dictionary objectForKey:keyWithDeviceSuffix];
    if (! valueForKeyWithDeviceSuffix)
    {
      id valueFromRegistrationDomainDefaults = [registrationDomainDefaults valueForKey:keyWithDeviceSuffix];
      [dictionary setValue:valueFromRegistrationDomainDefaults forKey:keyWithDeviceSuffix];
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Upgrades @a dictionary so that after the upgrade it no longer
/// contains device-specific keys that match the device-agnostic @a key.
// -----------------------------------------------------------------------------
+ (void) removeDeviceSpecificKeysForDeviceAgnosticKey:(NSString*)key fromDictionary:(NSMutableDictionary*)dictionary
{
  for (NSString* deviceSuffix in [UIDevice deviceSuffixes])
  {
    NSString* keyWithDeviceSuffix = [key stringByAppendingString:deviceSuffix];
    [dictionary removeObjectForKey:keyWithDeviceSuffix];
  }
}

@end
