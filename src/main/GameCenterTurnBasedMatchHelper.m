//
//  GameCenterTurnBasedMatchDelegate.m
//  Little Go
//
//  Created by Ben Jackson on 08/02/2015.
//
//

#import "GameCenterTurnBasedMatchHelper.h"
#import "GameCenterAuthenticationCommand.h"
#import "ApplicationDelegate.h"

#import "../player/Player.h"
#import "../player/PlayerModel.h"
#import "../newgame/NewGameModel.h"
#import "../go/GoGame.h"

#import "../command/game/LoadGameCommand.h"

@interface GameCenterTurnBasedMatchHelper()
@property (nonatomic, retain) ApplicationDelegate *appDelegate;
@end

@implementation GameCenterTurnBasedMatchHelper

// singleton implementation
static GameCenterTurnBasedMatchHelper *instance = nil;

+ (GameCenterTurnBasedMatchHelper*)sharedInstance
{
  if (!instance)
  {
    instance = [[GameCenterTurnBasedMatchHelper alloc] init];
  }
  
  return instance;
}

-(id)init
{
  self = [super init];
  if (!self)
    return nil;
  
  self.appDelegate = [ApplicationDelegate sharedDelegate];
  userAuthenticated = NO;
  
  return self;
}

-(void) dealloc
{
  self.appDelegate = nil;
  self.currentMatch = nil;
  [super dealloc];
}

/// @brief initailise game center by authenticating the local user
-(void)authenticateLocalUser
{
  GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
  if (localPlayer == nil)
  {
    return;
  }
  
  // setting the authentication handler implicitly (as a side-effect!) starts
  // the process of authentication
  localPlayer.authenticateHandler = ^(UIViewController *loginViewController,
                                      NSError *error)
  {
    if (loginViewController != nil)
    {
      //
      // we must display the login dialog asyncronously, as it is possible that
      // we are already presenting a HUD view controller due to
      // SetupApplicationCommand
      //
      
      DDLogVerbose(@"Game Center wants to display a view controller");
      [[[[GameCenterAuthenticationCommand alloc]
         initWithLoginViewController:loginViewController]
        autorelease]
       submit];
    }
    else if (localPlayer.isAuthenticated)
    {
      userAuthenticated = YES;
      
      // TODO: do whatever is needed to indicate that the player was
      // authenticated, such as enabling the option for multi-player
      DDLogInfo(@"Game Center authenticated player with ID %@",
                localPlayer.playerID);
      
      
      Player * gcPlayer = [self.appDelegate.playerModel playerForLocalPlayer:localPlayer];
      self.appDelegate.theNewGameModel.gameCenterLocalPlayerUUID = gcPlayer.uuid;
      
      // register for push notifications/updates to game center games
      [localPlayer registerListener:self];
    }
    else
    {
      // TODO: ensure that multi-player options are disabled
      // we don't need to do anything with the error
      // as the gamekit did whatver was required for us
      DDLogError(@"Game Center error: %@ (%@)",
                 error.localizedDescription,
                 error.localizedFailureReason);
    }
  };
 
}

-(uint32_t)maskForGame:(NewGameModel *)model
{
  //
  // Game center uses the mask to do matchmaking
  //
  // we have just 32 bits to play with
  //
  //
  // 0    : player is black (set) else player is white (unset)
  // 1-5  : go board size
  // 6    : scoring system
  // 7-8  : Ko rule
  // 9-12 : handica
  // 13-17: Komi (max value 16)
  // 18-31: reserved
  //
  // Special handling for handicap and komi:
  //
  // Handicap is represented as an int, but the UI restricts it to max of 9
  //
  // Komi is represented as a double. This is a pain, but the UI restricts
  // the set of values to the enum defined here
  //
  assert(model.gameTypeLastSelected == GoGameTypeGameCenter);
  uint32_t mask = 0;

  // set the play as black bit
  mask |= !((uint32_t)(model.computerPlaysWhite));
  
  // set the board size bits
  assert(model.boardSize < 32);
  mask |= (uint32_t)model.boardSize << 1;;
  
  // set the scoring system bits
  assert(model.scoringSystem < 2);
  mask |= (uint32_t)model.scoringSystem << 6;
  
  // set the ko rule bits
  assert(model.koRule < 4);
  mask |= (uint32_t)model.koRule << 7;
  
  // set the handicap bits
  assert (model.handicap < 16);
  assert (model.handicap >= 0);
  mask |= (uint32_t)model.handicap << 9;
  
  // set the komi bits (this is more difficult)
  //
  // each komi is some multiple of .5, so we just multiply
  // the komi by 2 to get an integer to fit in the space;
  
  uint32_t komi = (uint32_t)(model.komi * 2.0);
  assert(komi < 32);
  mask |= komi << 13;
  
  return mask;
}

-(void)switchTurn
{
  NSMutableArray *nextParticipants = [[NSMutableArray alloc] initWithCapacity:2];
  for (GKTurnBasedParticipant *participant in self.currentMatch.participants)
  {
    if ([[ApplicationDelegate sharedDelegate].playerModel isLocalGameCenterPlayer:participant.player])
    {
      [nextParticipants addObject:participant];
    }
    else
    {
      [nextParticipants insertObject:participant atIndex:0];
    }
  }
  
  NSData *matchData = [[GoGame sharedGame] dataForCurrentGameState];
  
  [self.currentMatch endTurnWithNextParticipants:nextParticipants
                                     turnTimeout:GKTurnTimeoutDefault
                                       matchData:matchData
                               completionHandler:nil];
  
}

/* GKChallengeListener, GKSavedGameListener: optional */

/* GKInviteEventListener */

// player:didAcceptInvite: gets called when another player accepts the invite from the local player
- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite
{
  DDLogInfo(@"player: %@ didAcceptInvite:", player.playerID);
}

// didRequestMatchWithRecipients: gets called when the player chooses to play with another player from Game Center and it launches the game to start matchmaking
- (void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray *)recipientPlayers
{
  DDLogInfo(@"player: %@ didRequestMatchWithRecipients:", player.playerID);
  
  //
  // TODO: issue a NewGameCommand in some sort of safe way, having initialised
  // the remote player automatically
  //
}

/* GKTurnBasedEventListener */

// If Game Center initiates a match the developer should create a GKTurnBasedMatch from playersToInvite and present a GKTurnbasedMatchmakerViewController.
- (void)player:(GKPlayer *)player didRequestMatchWithOtherPlayers:(NSArray *)playersToInvite
{
  DDLogInfo(@"player: %@ didrequestMatchWithOtherPlayers:", player.playerID);
  
  //
  // TODO: it isn't obvious how this differs from player:didRequestMatchWithRecipients
  //
}

// called when it becomes this player's turn.  It also gets called under the following conditions:
//      the player's turn has a timeout and it is about to expire.
//      the player accepts an invite from another player.
// when the game is running it will additionally recieve turn events for the following:
//      turn was passed to another player
//      another player saved the match data
// Because of this the app needs to be prepared to handle this even while the player is taking a turn in an existing match.  The boolean indicates whether this event launched or brought to forground the app.
- (void)player:(GKPlayer *)player receivedTurnEventForMatch:(GKTurnBasedMatch *)match didBecomeActive:(BOOL)didBecomeActive
{
  DDLogInfo(@"player: %@ receivedTurnEventForMatch: %@ didBecomeActive: %d",
               player.playerID,
               match.matchID,
               didBecomeActive);
  //
  // TODO: it is now our turn, or.. it might not be.
  //
  // this API seems irritatingly obtuse, and the Game Center programming guide
  // is out of date with respect to this API. Perhaps i need to watch the videos
  // or read some online turn-based tutorial since iOS7
  //
  self.currentMatch = match;
  //
  // set the properties in the NewGameModel which are not part of the API
  //
  self.appDelegate.theNewGameModel.gameType = GoGameTypeGameCenter;
  self.appDelegate.theNewGameModel.gameTypeLastSelected = GoGameTypeGameCenter;
  self.appDelegate.theNewGameModel.gcMatch = match;
  
  // TODO: setup computerPlaysWhite. We need some data in the matchdata which
  // says who is playing white. For now, the game assumes the initiator of
  // the game plays black (TODO: make this based on handicap?)
  //
  // In fact, it might seem more sensible in general to make the matchmaking
  // game start with an "exchange" which agrees the game rules (i want to play
  // with these settings... do you accept?) once the exchange ic complete, we
  // can pass the turn to black (if no handicap) or white otherwise via calls
  // to switchTurn.
  //
  // We can then encode the "newGameModel" directly into a 32 bit value on the
  // game data (we can use the endcoding set up in maskForGame:
  //
  if ([self.appDelegate.playerModel isLocalGameCenterPlayer:
                                      [match.participants objectAtIndex:0]])
  {
    self.appDelegate.theNewGameModel.computerPlaysWhite = YES;
  }
  else
  {
    self.appDelegate.theNewGameModel.computerPlaysWhite = NO;
  }
  
  for (GKTurnBasedParticipant * participant in match.participants)
  {
    if ([self.appDelegate.playerModel isLocalGameCenterPlayer:participant.player])
    {
      // we have the remote player
      Player * remotePlayer = [self.appDelegate.playerModel playerForRemotePlayer:participant.player];
      
      self.appDelegate.theNewGameModel.gameCenterRemotePlayerUUID = remotePlayer.uuid;
    }
  }
  [[[[LoadGameCommand alloc] initWithFileData:match.matchData] autorelease] submit];
  
}

// called when the match has ended.
- (void)player:(GKPlayer *)player matchEnded:(GKTurnBasedMatch *)match
{
  DDLogInfo(@"player: %@ matchEnded: %@", player.playerID, match.matchID);
  //
  // TODO: match ended.. why?
  //
}

// this is called when a player receives an exchange request from another player.
- (void)player:(GKPlayer *)player receivedExchangeRequest:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match
{
  DDLogInfo(@"player %@ receivedExchangeRequest: for match: %@",
               player.playerID,
               match.matchID);
  
  assert(false && "Exchanges are not currency supported");
}

// this is called when an exchange is canceled by the sender.
- (void)player:(GKPlayer *)player receivedExchangeCancellation:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match
{
  DDLogInfo(@"player %@ receivedExchangeCancellation: for match: %@",
               player.playerID,
               match.matchID);

  assert(false && "Exchanges are not currency supported");

}

// called when all players either respond or timeout responding to this request.  This is sent to both the turn holder and the initiator of the exchange
- (void)player:(GKPlayer *)player receivedExchangeReplies:(NSArray *)replies forCompletedExchange:(GKTurnBasedExchange *)exchange forMatch:(GKTurnBasedMatch *)match
{
  DDLogInfo(@"player %@ receivedExchangeReplies: for match: %@",
               player.playerID,
               match.matchID);
  
  assert(false && "Exchanges are not currency supported");
}

@end
