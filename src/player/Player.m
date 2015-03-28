// -----------------------------------------------------------------------------
// Copyright 2011-2013 Patrick Näf (herzbube@herzbube.ch)
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
#import "Player.h"
#import "PlayerStatistics.h"
#import "GtpEngineProfile.h"
#import "GtpEngineProfileModel.h"
#import "../utility/NSStringAdditions.h"
#import "../main/ApplicationDelegate.h"
#import "../go/GoGame.h"
#import "../go/GoPlayer.h"
#import "GameKit/GameKit.h"

// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for Player.
// -----------------------------------------------------------------------------
@interface Player()
/// @name Re-declaration of properties to make them readwrite privately
//@{
@property(nonatomic, retain, readwrite) NSString* uuid;
@property(nonatomic, retain, readwrite) NSString* gameCenterID;
//@}
@end


@implementation Player

// -----------------------------------------------------------------------------
/// @brief Initializes a Player object with a randomly generated UUID.
// -----------------------------------------------------------------------------
- (id) init
{
  // Invoke designated initializer
  return [self initWithDictionary:nil];
}

// -----------------------------------------------------------------------------
/// @brief Initializes a Player object with UUID @a uuid.
// -----------------------------------------------------------------------------
- (id) initWithUUID:(NSString*)uuid
{
  // Invoke designated initializer
  Player* player = [self initWithDictionary:nil];
  // Replace randomly generated UUID
  if (player)
    player.uuid = uuid;
  return player;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a Player object with user defaults data stored inside
/// @a dictionary.
///
/// If @a dictionary is @e nil, the Player object is human, has no name, and is
/// associated with a PlayerStatistics object that has all attributes set to
/// zero/undefined values. The UUID is randomly generated.
///
/// Invoke the asDictionary() method to convert a Player object's user defaults
/// attributes back into an NSDictionary suitable for storage in the user
/// defaults system.
///
/// @note This is the designated initializer of Player.
// -----------------------------------------------------------------------------
- (id) initWithDictionary:(NSDictionary*)dictionary
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;
  else if (! dictionary)
  {
    self.uuid = [NSString UUIDString];
    self.name = @"";
    self.human = true;
    self.remote = false;
    self.gameCenterID = @"";
    self.gtpEngineProfileUUID = @"";
    self.statistics = [[[PlayerStatistics alloc] init] autorelease];
  }
  else
  {
    self.uuid = (NSString*)[dictionary valueForKey:playerUUIDKey];
    self.name = (NSString*)[dictionary valueForKey:playerNameKey];
    // The value returned from the NSDictionary has the type NSCFBoolean. It
    // appears that this can be treated as an NSNumber object, from which we
    // can get the value by sending the message "boolValue".
    self.human = [[dictionary valueForKey:isHumanKey] boolValue];
    self.remote = [[dictionary valueForKey:isRemoteKey] boolValue];
    if (self.human)
      self.gtpEngineProfileUUID = @"";
    else
      self.gtpEngineProfileUUID = (NSString*)[dictionary valueForKey:gtpEngineProfileReferenceKey];
    NSDictionary* statisticsDictionary = (NSDictionary*)[dictionary valueForKey:statisticsKey];
    self.statistics = [[[PlayerStatistics alloc] initWithDictionary:statisticsDictionary] autorelease];
  }
  DDLogVerbose(@"%@: UUID = %@, name = %@", self, self.uuid, self.name);
  assert([self.uuid length] > 0);
  if ([self.uuid length] <= 0)
    DDLogError(@"%@: UUID length <= 0", self);
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Creates a local player object after a successful game center logic
// -----------------------------------------------------------------------------
- (id) initWithLocalPlayer:(GKLocalPlayer*)localPlayer
{
  self = [super init];
  if (!self)
  {
    return nil;
  }
  // TODO: else if (find from dictionary) ?
  else
  {
    assert(localPlayer.authenticated);
    self.uuid = [NSString UUIDString];
    self.name = [localPlayer displayName];
    self.human = true;
    self.remote = false;
    self.gameCenterID = [localPlayer playerID];
    self.gtpEngineProfileUUID = @"";
    self.statistics = [[[PlayerStatistics alloc] init] autorelease];
  }
  DDLogVerbose(@"%@: UUID = %@, name = %@ (gamecenter local)",
               self,
               self.uuid,
               self.name);
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Creates a local player object after a successful game center logic
// -----------------------------------------------------------------------------
- (id) initWithRemotePlayer:(GKPlayer *)remotePlayer
{
  self = [super init];
  if (!self)
  {
    return nil;
  }
  // TODO: else if (find from dictionary) ?
  else
  {
    assert(localPlayer.authenticated);
    self.uuid = [NSString UUIDString];
    self.name = [remotePlayer displayName];
    self.human = true;
    self.remote = true;
    self.gameCenterID = [remotePlayer playerID];
    self.gtpEngineProfileUUID = @"";
    self.statistics = [[[PlayerStatistics alloc] init] autorelease];
  }
  DDLogVerbose(@"%@: UUID = %@, name = %@ (gamecenter local)",
               self,
               self.uuid,
               self.name);
  return self;
}


// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this Player object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.uuid = nil;
  self.name = nil;
  self.gameCenterID = nil;
  self.gtpEngineProfileUUID = nil;
  self.statistics = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Returns this Player object's user defaults attributes as a dictionary
/// suitable for storage in the user defaults system.
// -----------------------------------------------------------------------------
- (NSDictionary*) asDictionary
{
  NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
  // setValue:forKey:() allows for nil values, so we use that instead of
  // setObject:forKey:() which is less forgiving and would force us to check
  // for nil values.
  // Note: Use NSNumber to represent int and bool values as an object.
  [dictionary setValue:self.uuid forKey:playerUUIDKey];
  [dictionary setValue:self.name forKey:playerNameKey];
  [dictionary setValue:[NSNumber numberWithBool:self.isHuman] forKey:isHumanKey];
  if (! self.isHuman)
    [dictionary setValue:self.gtpEngineProfileUUID forKey:gtpEngineProfileReferenceKey];
  [dictionary setValue:[self.statistics asDictionary] forKey:statisticsKey];
  return dictionary;
}

// -----------------------------------------------------------------------------
/// @brief Returns the GtpEngineProfile object that this Player references via
/// the @e gtpEngineProfileUUID property.
///
/// Returns nil if this Player is not a computer player (i.e. isHuman() returns
/// true).
///
/// This is a convenience method so that clients do not need to know
/// GtpEngineProfileModel, or how to obtain an instance of
/// GtpEngineProfileModel.
// -----------------------------------------------------------------------------
- (GtpEngineProfile*) gtpEngineProfile
{
  if (self.isHuman)
    return nil;
  GtpEngineProfileModel* model = [ApplicationDelegate sharedDelegate].gtpEngineProfileModel;
  return [model profileWithUUID:self.gtpEngineProfileUUID];
}

// -----------------------------------------------------------------------------
/// @brief Sets whether this Player object represents a human player to
/// @a newValue. As a side-effect, also adjusts @e gtpEngineProfileUUID.
///
/// If after the change this Player object represents a human player,
/// @e gtpEngineProfileUUID is set to an empty string. Otherwise
/// @e gtpEngineProfileUUID is set to reference the default GtpEngineProfile.
// -----------------------------------------------------------------------------
- (void) setHuman:(bool)newValue
{
  if (_human == newValue)
    return;
  _human = newValue;
  if (_human)
    self.gtpEngineProfileUUID = @"";
  else
  {
    GtpEngineProfileModel* model = [ApplicationDelegate sharedDelegate].gtpEngineProfileModel;
    self.gtpEngineProfileUUID = [model defaultProfile].uuid;
  }
}

// -----------------------------------------------------------------------------
// Property is documented in the header file.
// -----------------------------------------------------------------------------
- (bool) isPlaying
{
  GoGame* game = [GoGame sharedGame];
  if (! game)
    return false;
  else if ([self.uuid isEqualToString:game.playerBlack.player.uuid])
    return true;
  else if ([self.uuid isEqualToString:game.playerWhite.player.uuid])
    return true;
  return false;
}

@end
