//
//  GameCenterTurnBasedMatchDelegate.h
//  Little Go
//
//  Created by Ben Jackson on 08/02/2015.
//
//

#import <GameKit/GameKit.h>

@class NewGameModel;

@interface GameCenterTurnBasedMatchHelper : NSObject<GKLocalPlayerListener>
{
  BOOL userAuthenticated;
}

@property (nonatomic, retain) GKTurnBasedMatch *currentMatch;

/// @brief returns the one and only instance of this class
+ (GameCenterTurnBasedMatchHelper*) sharedInstance;

-(void)authenticateLocalUser;

-(uint32_t)maskForGame:(NewGameModel *)model;

-(void)switchTurn;


@end
