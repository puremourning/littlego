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


// Forward declarations
@class Player;
@class GKPlayer;
@class GKLocalPlayer;

// -----------------------------------------------------------------------------
/// @brief The PlayerModel class manages Player objects and provides clients
/// with access to those objects. Data that makes up Player objects is read
/// from and written to the user defaults system.
// -----------------------------------------------------------------------------
@interface PlayerModel : NSObject
{
}

- (id) init;
- (void) readUserDefaults;
- (void) writeUserDefaults;
- (void) resetToRegistrationDomainDefaults;
- (NSString*) playerNameAtIndex:(int)index;
- (void) add:(Player*)player;
- (void) remove:(Player*)player;
- (Player*) playerWithUUID:(NSString*)uuid;
- (NSArray*) playerListHuman:(bool)human;
- (BOOL) isLocalGameCenterPlayer:(GKPlayer*)player;
- (Player*) playerForLocalPlayer:(GKLocalPlayer*)localPlayer;
- (Player*) playerForRemotePlayer:(GKPlayer*)remotePlayer;
- (Player*) getDefaultRemoteGameCenterPlayer;

@property(nonatomic, assign) int playerCount;
@property(nonatomic, retain) NSArray* playerList;

@end
