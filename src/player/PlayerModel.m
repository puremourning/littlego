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
#import "PlayerModel.h"
#import "Player.h"

#import <GameKit/GameKit.h>

@interface PlayerModel()

@property (nonatomic,retain,readwrite) GKLocalPlayer* localGameCenterPlayer;

@end

@implementation PlayerModel

// -----------------------------------------------------------------------------
/// @brief Initializes a PlayerModel object with user defaults data.
///
/// @note This is the designated initializer of PlayerModel.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;
  self.playerCount = 0;
  self.playerList = [NSMutableArray arrayWithCapacity:self.playerCount];
  self.localGameCenterPlayer = nil;
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PlayerModel object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.playerList = nil;
  self.localGameCenterPlayer = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Initializes default values in this model with user defaults data.
// -----------------------------------------------------------------------------
- (void) readUserDefaults
{
  NSMutableArray* localPlayerList = [NSMutableArray array];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray* userDefaultsPlayerList = [userDefaults arrayForKey:playerListKey];
  for (NSDictionary* playerDictionary in userDefaultsPlayerList)
  {
    Player* player = [[Player alloc] initWithDictionary:playerDictionary];
    // We want the array to retain and release the object for us -> decrease
    // the retain count by 1 (was set to 1 by alloc/init)
    [player autorelease];
    [localPlayerList addObject:player];
  }
  // Cast is required because NSUInteger and int differ in size in 64-bit. Cast
  // is safe because we can never have more than pow(2, 32) players
  self.playerCount = (int)[localPlayerList count];
  // Completely replace the previous player list to trigger the
  // key-value-observing mechanism.
  self.playerList = localPlayerList;
}

// -----------------------------------------------------------------------------
/// @brief Writes current values in this model to the user default system's
/// application domain.
// -----------------------------------------------------------------------------
- (void) writeUserDefaults
{
  NSMutableArray* userDefaultsPlayerList = [NSMutableArray array];
  for (Player* player in self.playerList)
    [userDefaultsPlayerList addObject:[player asDictionary]];
  // Note: NSUserDefaults takes care entirely by itself of writing only changed
  // values.
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:userDefaultsPlayerList forKey:playerListKey];
}

// -----------------------------------------------------------------------------
/// @brief Discards the current user defaults and re-initializes this model with
/// registration domain defaults data.
// -----------------------------------------------------------------------------
- (void) resetToRegistrationDomainDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults removeObjectForKey:playerListKey];
  [self readUserDefaults];
}

// -----------------------------------------------------------------------------
/// @brief Returns the name of the player at position @a index in the list of
/// players. This is a convenience method.
// -----------------------------------------------------------------------------
- (NSString*) playerNameAtIndex:(int)index
{
  assert(index >= 0 && index < [self.playerList count]);
  Player* player = (Player*)[self.playerList objectAtIndex:index];
  return player.name;
}

// -----------------------------------------------------------------------------
/// @brief Adds object @a player to this model.
// -----------------------------------------------------------------------------
- (void) add:(Player*)player
{
  NSMutableArray* localPlayerList = (NSMutableArray*)self.playerList;
  [localPlayerList addObject:player];
  // Cast is required because NSUInteger and int differ in size in 64-bit. Cast
  // is safe because we can never have more than pow(2, 32) players
  self.playerCount = (int)[localPlayerList count];
}

// -----------------------------------------------------------------------------
/// @brief Removes object @a player from this model.
// -----------------------------------------------------------------------------
- (void) remove:(Player*)player
{
  NSMutableArray* localPlayerList = (NSMutableArray*)self.playerList;
  [localPlayerList removeObject:player];
  // Cast is required because NSUInteger and int differ in size in 64-bit. Cast
  // is safe because we can never have more than pow(2, 32) players
  self.playerCount = (int)[localPlayerList count];
}

// -----------------------------------------------------------------------------
/// @brief Returns the player object identified by @a uuid. Returns nil if no
/// such object exists.
// -----------------------------------------------------------------------------
- (Player*) playerWithUUID:(NSString*)uuid
{
  for (Player* player in self.playerList)
  {
    if ([player.uuid isEqualToString:uuid])
      return player;
  }
  return nil;
}

// -----------------------------------------------------------------------------
/// @brief Returns a filtered list of player objects where all players are
/// either humans (@a human is true) or computers (@a human is false).
// -----------------------------------------------------------------------------
- (NSArray*) playerListHuman:(bool)human
{
  NSMutableArray* filteredPlayerList = [NSMutableArray arrayWithCapacity:0];
  for (Player* player in self.playerList)
  {
    if (human != player.human && player.remote != true)
      continue;
    [filteredPlayerList addObject:player];
  }
  return filteredPlayerList;
}

/// @brief returns the Player object for the supplied game center playre
///
/// if the a Player object doesn't already exist for the supplied game cneter
/// player, then one is created
///
-(Player*)playerForLocalPlayer:(GKLocalPlayer*)localPlayer
{
  // hack: we're assuming this method is called because the localplayer just
  // authorised. this isn't so bad, as there can only be one localplayer
  self.localGameCenterPlayer = localPlayer;
  
  // first see if there is a player already
  for(Player *player in self.playerList)
  {
    if (player.isHuman && !player.isRemote &&
        [player.gameCenterID isEqualToString:localPlayer.playerID])
    {
      return player;
    }
  }
  
  // we didn't find it, return a new one
  Player *gcPlayer = [[[Player alloc] initWithLocalPlayer:localPlayer] autorelease];
  [self add:gcPlayer];
  
  return gcPlayer;
}

/// @brief returns the Player object for the supplied game center playre
///
/// if the a Player object doesn't already exist for the supplied game cneter
/// player, then one is created
///
-(Player*)playerForRemotePlayer:(GKPlayer *)remotePlayer
{
  // first see if there is a player already
  for(Player *player in self.playerList)
  {
    if (player.isHuman && player.isRemote &&
        [player.gameCenterID isEqualToString:remotePlayer.playerID])
    {
      return player;
    }
  }
  
  // we didn't find it, return a new one
  Player *gcPlayer = [[[Player alloc] initWithRemotePlayer:remotePlayer] autorelease];
  [self add:gcPlayer];
  
  return gcPlayer;
}

/// @brief returns whether or not the supplied game center playre is a local
///
/// TODO: This is broken if the same player can exist as both local and remote
/// (e.g. plays a local game, then someone else logs in and plays against
/// original player as the remote)
///
/// This should really be handled by storing the GKLocalPlayer object or game
/// center ID after authentication.
///

- (BOOL) isLocalGameCenterPlayer:(GKPlayer *)gkPlayer
{
  return [gkPlayer.playerID isEqualToString:self.localGameCenterPlayer.playerID];
}

///
/// @brief return a temporary Player object to represent the remote player
///
/// When matchmaking, game kit returns to us even if not all of the game "slots"
/// are filled. This means that when starting a new game we don't yet know
/// the deatils of the remote player. So to work around this, we have a "default"
/// player object which just rempresets any remote player. For this we use
/// the hacky approach of a remote player with no name
///
/// TODO: The empty named player causes a UI bug in the playaer management
/// screen, so we should either filter it out or fix this hack
///
- (Player*)getDefaultRemoteGameCenterPlayer
{
  for (Player *player in self.playerList)
  {
    if (player.isHuman && player.isRemote &&
        [player.gameCenterID isEqualToString:@""])
    {
      return player;
    }
  }
  
  // not found, create it
  Player *player = [[[Player alloc] initWithDictionary:nil] autorelease];
  player.human = true;
  player.remote = true;
  
  [self add:player];
  
  return player;
}

@end
