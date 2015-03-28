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
#import "NewGameCommand.h"
#import "../move/ComputerPlayMoveCommand.h"
#import "../../main/ApplicationDelegate.h"
#import "../../main/GameCenterTurnBasedMatchHelper.h"
#import "../../gtp/GtpCommand.h"
#import "../../gtp/GtpResponse.h"
#import "../../gtp/GtpUtilities.h"
#import "../../go/GoBoard.h"
#import "../../go/GoGame.h"
#import "../../go/GoGameRules.h"
#import "../../go/GoPlayer.h"
#import "../../go/GoScore.h"
#import "../../go/GoUtilities.h"
#import "../../player/Player.h"
#import "../../player/PlayerModel.h"
#import "../../newgame/NewGameModel.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for NewGameCommand.
// -----------------------------------------------------------------------------
@interface NewGameCommand()
@property(nonatomic, assign) GoGame* prefabricatedGame;
@property(nonatomic, retain) GKTurnBasedMatch* turnBasedMatch;
@end


@implementation NewGameCommand

// -----------------------------------------------------------------------------
/// @brief Initializes a NewGameCommand object that creates its own GoGame
/// instance.
// -----------------------------------------------------------------------------
- (id) init
{
  return [self initWithGame:nil];
}

//
/// @brief start a new game with the newly returned GKTurnBasedMatch
//
- (id) initWithTurnBasedMatch:(GKTurnBasedMatch *)match
{
  self = [self initWithGame:nil];
  
  self.turnBasedMatch = match;
  
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a NewGameCommand object. If @a game is not nil,
/// NewGameCommand will use this pre-fabricated GoGame object for its operation.
/// If @a game is nil, NewGameCommand will create its own GoGame instance.
///
/// @note This is the designated initializer of NewGameCommand.
// -----------------------------------------------------------------------------
- (id) initWithGame:(GoGame*)game
{
  // Call designated initializer of superclass (CommandBase)
  self = [super init];
  if (! self)
    return nil;

  self.prefabricatedGame = game;
  self.turnBasedMatch = nil;
  
  self.shouldSetupGtpBoard = true;
  self.shouldSetupGtpHandicapAndKomi = true;
  self.shouldSetupComputerPlayer = true;
  self.shouldTriggerComputerPlayer = true;
  return self;
}

-(void)dealloc
{
  self.turnBasedMatch = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  [self newGame];
  [self setupGtpRules];
  if (self.shouldSetupGtpBoard)
    [self setupGtpBoard];
  if (self.shouldSetupGtpHandicapAndKomi)
    [self setupGtpHandicapAndKomi];
  if (self.shouldSetupComputerPlayer)
    [GtpUtilities setupComputerPlayer];
  
  if (self.shouldTriggerComputerPlayer)
  {
    [self triggerComputerPlayer];
    [self startGameCenterMatch];
  }
  
  return true;
}

// -----------------------------------------------------------------------------
/// @brief Creates a new GoGame instance (deallocates the old one first).
// -----------------------------------------------------------------------------
- (void) newGame
{
  // Disable scoring mode while the old GoGame is still around
  GoGame* oldGame = [GoGame sharedGame];
  oldGame.score.scoringEnabled = false;

  // Send this while the old GoGame object is still around and fully functional
  // (the old game is nil if this happens during application startup)
  [[NSNotificationCenter defaultCenter] postNotificationName:goGameWillCreate object:oldGame];

  // Create the new GoGame object (unless a pre-fabricated object was supplied)
  // TODO: Prevent starting a new game if the defaults are somehow invalid
  // (currently known: player UUID may refer to a player that has been removed)
  GoGame* newGame;
  if (! self.prefabricatedGame)
  {
    newGame = [[[GoGame alloc] init] autorelease];
    DDLogVerbose(@"%@: Created new game %@", [self shortDescription], newGame);
  }
  else
  {
    newGame = self.prefabricatedGame;
    DDLogVerbose(@"%@: Using pre-fabricated game %@", [self shortDescription], newGame);
  }

  // Replace the delegate's reference; an old GoGame object is now deallocated
  ApplicationDelegate* appDelegate = [ApplicationDelegate sharedDelegate];
  appDelegate.game = newGame;
  DDLogVerbose(@"%@: Assigned game object to app delegate", [self shortDescription]);

  // Configure the new GoGame object (not necessary for pre-fabricated games)
  if (! self.prefabricatedGame)
  {
    NewGameModel* newGameModel = appDelegate.theNewGameModel;
    newGame.board = [GoBoard boardWithDefaultSize];
    newGame.komi = newGameModel.komi;
    newGame.handicapPoints = [GoUtilities pointsForHandicap:newGameModel.handicap inGame:newGame];
    newGame.playerBlack = [GoPlayer defaultBlackPlayer];
    if (! newGame.playerBlack)
    {
      [self createEmergencyPlayerUsingColor:GoColorBlack];
      newGame.playerBlack = [GoPlayer defaultBlackPlayer];
    }
    newGame.playerWhite = [GoPlayer defaultWhitePlayer];
    if (! newGame.playerWhite)
    {
      [self createEmergencyPlayerUsingColor:GoColorWhite];
      newGame.playerWhite = [GoPlayer defaultWhitePlayer];
    }
    newGame.type = newGameModel.gameType;
    newGame.rules.koRule = newGameModel.koRule;
    newGame.rules.scoringSystem = newGameModel.scoringSystem;
    
    if (newGameModel.gameType == GoGameTypeGameCenter)
    {
      // TODO: this feels a lot like a hack, like it should be
      // NewGameController that does this?
      [GameCenterTurnBasedMatchHelper sharedInstance].currentMatch = newGameModel.gcMatch;
    }
  }
  DDLogVerbose(@"%@: Game object configuration: board = %@, komi = %.1f, handicapPoints = %@, playerBlack = %@ (uuid = %@), playerWhite = %@ (uuid = %@), type = %d, ko rule = %d, scoring = %d",
               [self shortDescription],
               newGame.board,
               newGame.komi,
               newGame.handicapPoints,
               newGame.playerBlack,
               newGame.playerBlack.player.uuid,
               newGame.playerWhite,
               newGame.playerWhite.player.uuid,
               newGame.type,
               newGame.rules.koRule,
               newGame.rules.scoringSystem);

  // Send this only after GoGame and its dependents have been fully configured.
  // Receivers will probably want to know stuff like the board size and what
  // game type this is.
  [[NSNotificationCenter defaultCenter] postNotificationName:goGameDidCreate object:newGame];
}

// -----------------------------------------------------------------------------
/// @brief Creates a new Player object that matches the characteristics in
/// NewGameModel for color @a color.
///
/// This is a private helper for newGame().
///
/// This method is designed to be invoked as an emergency (e.g. during
/// application launch) when the user preferences in NewGameModel refer to a
/// Player that does not exist in the user preferences in PlayerModel. This
/// method fixes the inconsistency in the user preferences data by creating a
/// new Player object.
///
/// When this method returns, the caller can expect that invoking either
/// GoPlayer::defaultBlackPlayer() or GoPlayer::defaultWhitePlayer() (which it
/// is depends on @a color) will return a valid GoPlayer object.
// -----------------------------------------------------------------------------
- (void) createEmergencyPlayerUsingColor:(enum GoColor)color
{
  ApplicationDelegate* appDelegate = [ApplicationDelegate sharedDelegate];
  NewGameModel* newGameModel = appDelegate.theNewGameModel;
  PlayerModel* playerModel = appDelegate.playerModel;

  NSString* playerUUID = nil;
  bool playerIsBlack;
  switch (color)
  {
    case GoColorBlack:
    {
      playerUUID = [newGameModel blackPlayerUUID];
      playerIsBlack = true;
      break;
    }
    case GoColorWhite:
    {
      playerUUID = [newGameModel whitePlayerUUID];
      playerIsBlack = false;
      break;
    }
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Illegal GoColor value %d", color];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSGenericException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }

  Player* newPlayer = [[[Player alloc] initWithUUID:playerUUID] autorelease];
  bool newPlayerIsHuman;
  switch (newGameModel.gameType)
  {
    case GoGameTypeHumanVsHuman:
    {
      newPlayerIsHuman = true;
      break;
    }
    case GoGameTypeComputerVsComputer:
    {
      newPlayerIsHuman = false;
      break;
    }
    case GoGameTypeComputerVsHuman:
    {
      if (newGameModel.computerPlaysWhite)
        newPlayerIsHuman = playerIsBlack;
      else
        newPlayerIsHuman = !playerIsBlack;
      break;
    }
    case GoGameTypeGameCenter:
    {
      newPlayerIsHuman = true;
      if (newGameModel.computerPlaysWhite)
      {
        newPlayer.remote = playerIsBlack;
      }
      else
      {
        newPlayer.remote = !playerIsBlack;
      }
      newPlayer.remote = true;
      break;
    }
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Illegal GoGameType value %d", newGameModel.gameType];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSGenericException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }
  newPlayer.human = newPlayerIsHuman;
  newPlayer.name = @"Auto-created player";
  [playerModel add:newPlayer];

  NSString* errorMessage = [NSString stringWithFormat:@"Auto-created new Player object, UUID = %@, name = %@, human = %d",
                            newPlayer.uuid,
                            newPlayer.name,
                            newPlayer.human];
  DDLogError(@"%@: %@", [self shortDescription], errorMessage);
}

// -----------------------------------------------------------------------------
/// @brief Configures the GTP engine with a number of rules how to play the
/// game.
// -----------------------------------------------------------------------------
- (void) setupGtpRules
{
  [self setupKoRule];
  [self setupScoringSystem];
}

// -----------------------------------------------------------------------------
/// @brief Configures the GTP engine with the ko rule to use.
// -----------------------------------------------------------------------------
- (void) setupKoRule
{
  enum GoKoRule koRule = [GoGame sharedGame].rules.koRule;
  NSString* gtpKoRuleName;
  switch (koRule)
  {
    case GoKoRuleSimple:
      gtpKoRuleName = @"simple";
      break;
    case GoKoRuleSuperkoPositional:
      gtpKoRuleName = @"pos_superko";
      break;
    case GoKoRuleSuperkoSituational:
      gtpKoRuleName = @"superko";
      break;
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Illegal GoKoRule value %d", koRule];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSGenericException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }
  NSString* commandString = [NSString stringWithFormat:@"go_param_rules ko_rule %@", gtpKoRuleName];
  [[GtpCommand command:commandString] submit];
}

// -----------------------------------------------------------------------------
/// @brief Configures the GTP engine with the scoring system to use.
// -----------------------------------------------------------------------------
- (void) setupScoringSystem
{
  enum GoScoringSystem scoringSystem = [GoGame sharedGame].rules.scoringSystem;
  int japaneseScoring;
  switch (scoringSystem)
  {
    case GoScoringSystemAreaScoring:
      japaneseScoring = 0;
      break;
    case GoScoringSystemTerritoryScoring:
      japaneseScoring = 1;
      break;
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Illegal GoScoringSystem value %d", scoringSystem];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSGenericException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }
  NSString* commandString = [NSString stringWithFormat:@"go_param_rules japanese_scoring %d", japaneseScoring];
  [[GtpCommand command:commandString] submit];
}

// -----------------------------------------------------------------------------
/// @brief Performs the board setup of the GTP engine using values obtained
/// from the current GoGame.
// -----------------------------------------------------------------------------
- (void) setupGtpBoard
{
  GoBoard* board = [GoGame sharedGame].board;
  [[GtpCommand command:@"clear_board"] submit];
  [[GtpCommand command:[NSString stringWithFormat:@"boardsize %d", board.size]] submit];
}

// -----------------------------------------------------------------------------
/// @brief Performs handicap and komi setup of the GTP engine using values
/// obtained from the current GoGame.
// -----------------------------------------------------------------------------
- (void) setupGtpHandicapAndKomi
{
  GoGame* game = [GoGame sharedGame];

  // Setup handicap only if there is one. The GTP command "fixed_handicap"
  // accepts only values >= 2. This should not be a problem since our own
  // handicap selection screen does not offer to select handicap 1.
  NSUInteger handicap = game.handicapPoints.count;
  if (handicap >= 2)
  {
    GtpCommand* commandFixedHandicap = [GtpCommand command:[NSString stringWithFormat:@"fixed_handicap %lu", (unsigned long)handicap]];
    [commandFixedHandicap submit];
    assert(commandFixedHandicap.response.status);
  }

  // There is no universal default value for komi, so to be on the sure side we
  // always have to setup komi.
  GtpCommand* commandKomi = [GtpCommand command:[NSString stringWithFormat:@"komi %.1f", game.komi]];
  [commandKomi submit];
  assert(commandKomi.response.status);
}

// -----------------------------------------------------------------------------
/// @brief Triggers the computer player to make a move, if it is his turn.
// -----------------------------------------------------------------------------
- (void) triggerComputerPlayer
{
  if ([[GoGame sharedGame] isComputerPlayersTurn])
    [[[[ComputerPlayMoveCommand alloc] init] autorelease] submit];
}

-(void) startGameCenterMatch
{
  GKTurnBasedMatch * match = [GameCenterTurnBasedMatchHelper sharedInstance].currentMatch;
  ApplicationDelegate * appDelegate = [ApplicationDelegate sharedDelegate];
  if (match.status == GKTurnBasedExchangeStatusActive &&
      [appDelegate.playerModel isLocalGameCenterPlayer:match.currentParticipant.player])
  {
    //
    // it is our turn
    //
    if (appDelegate.theNewGameModel.computerPlaysWhite)
    {
      // it really is our turn, so we need to make a move
    }
    else
    {
      // it is the other player's turn
      [[GameCenterTurnBasedMatchHelper sharedInstance] switchTurn];
    }
  }
}

@end
