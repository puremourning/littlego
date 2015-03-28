// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
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
@class PlayerStatistics;
@class GtpEngineProfile;
@class GKLocalPlayer;
@class GKPlayer;


// -----------------------------------------------------------------------------
/// @brief The Player class collects data used to describe a Go player (e.g.
/// player name, whether the player is human or computer, etc.).
///
/// The difference between the Player and the GoPlayer class is that Player
/// refers to an @e identity, whereas GoPlayer refers to an anonymous black or
/// white player. GoPlayer can be configured with a reference to a Player
/// object, thus bringing the Player object's identity into the context of the
/// concrete GoGame that the GoPlayer instance is associated with.
///
/// If a Player object represents a computer player (i.e. isHuman() returns
/// false), the Player object has an associated collection of settings that
/// define the behaviour of the GTP engine while this Player participates in a
/// game. This collection of settings is called a "GTP engine profile". At
/// runtime the convenience method gtpEngineProfile() returns an object that
/// encapsulates the settings collection. The actual reference is stored in
/// the property @e gtpEngineProfileUUID, which is read from and written to the
/// user defaults system.
// -----------------------------------------------------------------------------
@interface Player : NSObject
{
}

- (id) init;
- (id) initWithUUID:(NSString*)uuid;
- (id) initWithDictionary:(NSDictionary*)dictionary;
- (id) initWithLocalPlayer:(GKLocalPlayer*)localPlayer;
- (id) initWithRemotePlayer:(GKPlayer*)remotePlayer;
- (NSDictionary*) asDictionary;
- (GtpEngineProfile*) gtpEngineProfile;

/// @brief The player's UUID. This is a technical identifier guaranteed to be
/// unique. This identifier is never displayed in the GUI.
@property(nonatomic, retain, readonly) NSString* uuid;
/// @brief. If this player is a Game Center player (i.e. a human or remote
/// player generated due to either a local game center authentication, or
/// the initiation of a game center game), this property holds the Game Center
/// generated/designated unique ID. For non-game-center players, this property
/// is empty
@property(nonatomic, retain, readonly) NSString* gameCenterID;

/// @brief The player's name. This is displayed in the GUI.
@property(nonatomic, retain) NSString* name;
/// @brief True if this Player object represents a human player, false if it
/// represents a computer player.
@property(nonatomic, assign, getter=isHuman) bool human;
/// @brief. True if this is a remote human player (that is, a Game Center
/// non-local player
@property(nonatomic, assign, getter=isRemote) bool remote;
/// @brief UUID of the GTP engine profile used by this Player. This ID is used
/// by gtpEngineProfile() to obtain and return a GtpEngineProfile object.
///
/// This property holds an empty string if this Player is not a computer player
/// (i.e. isHuman() returns true).
@property(nonatomic, retain) NSString* gtpEngineProfileUUID;
/// @brief Reference to an object that stores statistics about the history of
/// games played by this Player.
@property(nonatomic, retain) PlayerStatistics* statistics;
/// @brief True if this Player object is taking part in the currently ongoing
/// GoGame.
@property(nonatomic, assign, readonly, getter=isPlaying) bool playing;

@end
