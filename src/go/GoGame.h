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
@class GoBoard;
@class GoBoardPosition;
@class GoGameDocument;
@class GoGameRules;
@class GoMove;
@class GoMoveModel;
@class GoPlayer;
@class GoPoint;
@class GoScore;


// -----------------------------------------------------------------------------
/// @brief The GoGame class represents a game of Go.
///
/// @ingroup go
///
/// GoGame can be viewed as taking the role of a model in an MVC pattern that
/// includes the views and controllers in #UIAreaPlay. Clients that run one of
/// the various commands (e.g. #PlayMoveCommand) will trigger updates in GoGame
/// that can be observed by registering with the default NSNotificationCenter.
/// See Constants.h for a list of notifications that can be observed.
///
/// Although it is possible to create multiple instances of GoGame, there is
/// usually no point in doing so, except for unit testing purposes. During the
/// normal course of the applications's lifetime the following situations can
/// therefore be observed:
/// - No GoGame object exists: This is the case only for a brief period while
///   the application starts up.
/// - One GoGame object exists: This situtation exists during most of the
///   application's lifetime. This GoGame instance represents the game that is
///   currently in progress or that has just ended. The instance can be accessed
///   by invoking the class method sharedGame().
/// - Two GoGame objects exist: This situation occurs only for a brief moment
///   while a new game is being started. One of the GoGame objects is the game
///   that is going to be discarded, but is still available via sharedGame().
///   The other GoGame objects is the new game that is still in the process of
///   being configured. Access to this new GoGame object is not available yet.
///   The new GoGame object becomes officially available via sharedGame() when
///   the notification #goGameDidCreate is being sent.
// -----------------------------------------------------------------------------
@interface GoGame : NSObject <NSCoding>
{
}

+ (GoGame*) sharedGame;
- (void) play:(GoPoint*)point;
- (void) pass;
- (void) resign;
- (void) pause;
- (void) continue;
- (bool) isLegalMove:(GoPoint*)point isIllegalReason:(enum GoMoveIsIllegalReason*)reason;
- (bool) isComputerPlayersTurn;
- (bool) isRemotePlayersTurn;
- (void) revertStateFromEndedToInProgress;

- (NSData*)dataForCurrentGameState;

/// @brief The type of this GoGame object.
@property(nonatomic, assign) enum GoGameType type;
/// @brief The GoBoard object associated with this GoGame instance.
@property(nonatomic, retain) GoBoard* board;
/// @brief List of GoPoint objects with handicap stones.
///
/// Setting this property causes a black stone to be set on the GoPoint objects
/// in the specified list.
///
/// Raises an @e NSInternalInconsistencyException if this property is set when
/// this GoGame object is not in state #GoGameStateGameHasStarted, or if it is
/// in that state but already has moves. Summing it up, this property can be set
/// only at the start of the game.
///
/// Raises @e NSInvalidArgumentException if this property is set with a nil
/// value.
@property(nonatomic, retain) NSArray* handicapPoints;
/// @brief The komi used for this game.
@property(nonatomic, assign) double komi;
/// @brief The GoPlayer object that plays for black.
@property(nonatomic, retain) GoPlayer* playerBlack;
/// @brief The GoPlayer object that plays for white.
@property(nonatomic, retain) GoPlayer* playerWhite;
/// @brief The player whose turn it is now.
///
/// After the game has ended, querying this property in some cases is a
/// convenient way to find out who brought about the end of the game. For
/// instance, if the game was resigned this denotes the player who resigned.
@property(nonatomic, assign, readonly) GoPlayer* currentPlayer;
/// @brief The model object that stores the moves of the game.
@property(nonatomic, retain) GoMoveModel* moveModel;
/// @brief The GoMove object that represents the first move of the game. nil if
/// no moves have been made yet.
///
/// This is a convenience property that serves as a shortcut so that clients do
/// not have to obtain the desired GoMove object from @e moveModel.
@property(nonatomic, assign, readonly) GoMove* firstMove;
/// @brief The GoMove object that represents the last move of the game. nil if
/// no moves have been made yet.
///
/// This is a convenience property that serves as a shortcut so that clients do
/// not have to obtain the desired GoMove object from @e moveModel.
@property(nonatomic, assign, readonly) GoMove* lastMove;
/// @brief The state of the game.
@property(nonatomic, assign) enum GoGameState state;
/// @brief The reason why the game has reached the state #GoGameStateGameHasEnded.
@property(nonatomic, assign) enum GoGameHasEndedReason reasonForGameHasEnded;
/// @brief Returns true if the computer player is currently busy thinking about
/// something (typically its next move).
@property(nonatomic, assign, readonly, getter=isComputerThinking) bool computerThinks;
/// @brief The reason why the computer is busy.
@property(nonatomic, assign) enum GoGameComputerIsThinkingReason reasonForComputerIsThinking;
/// @brief The model object that defines defines which position of the Go board
/// is currently described by the GoPoint and GoBoardRegion objects attached to
/// this GoGame.
@property(nonatomic, retain) GoBoardPosition* boardPosition;
/// @brief Defines the rules that are in effect for this GoGame.
@property(nonatomic, retain) GoGameRules* rules;
/// @brief Represents this GoGame as a document that can be saved to / loaded
/// from disk.
@property(nonatomic, retain) GoGameDocument* document;
/// @brief The GoScore object that provides scoring information about this
/// GoGame.
@property(nonatomic, retain) GoScore* score;

@end
