// -----------------------------------------------------------------------------
// Copyright 2013-2014 Patrick Näf (herzbube@herzbube.ch)
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
#import "RestoreApplicationStateCommand.h"
#import "../boardposition/SyncGTPEngineCommand.h"
#import "../game/NewGameCommand.h"
#import "../playerinfluence/ToggleTerritoryStatisticsCommand.h"
#import "../../go/GoBoard.h"
#import "../../go/GoGame.h"
#import "../../go/GoMove.h"
#import "../../go/GoScore.h"
#import "../../go/GoZobristTable.h"
#import "../../utility/PathUtilities.h"


@implementation RestoreApplicationStateCommand

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  BOOL fileExists;
  NSString* archiveFilePath = [PathUtilities filePathForBackupFileNamed:archiveBackupFileName
                                                             fileExists:&fileExists];
  if (! fileExists)
  {
    DDLogVerbose(@"%@: Restoring not possible, NSCoding archive file does not exist: %@", [self shortDescription], archiveFilePath);
    return false;
  }

  NSData* data = [NSData dataWithContentsOfFile:archiveFilePath];
  NSKeyedUnarchiver* unarchiver;
  @try
  {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
  }
  @catch (NSException* exception)
  {
    DDLogError(@"%@: Restoring not possible, NSKeyedUnarchiver's initForReadingWithData raises exception, exception name = %@, reason = %@", [self shortDescription], exception.name, exception.reason);
    NSFileManager* fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager removeItemAtPath:archiveFilePath error:nil];
    DDLogVerbose(@"%@: Removed archive file %@, result = %d", [self shortDescription], archiveFilePath, result);
    return false;
  }
  GoGame* unarchivedGame = [unarchiver decodeObjectForKey:nsCodingGoGameKey];
  [unarchiver finishDecoding];
  [unarchiver release];
  if (! unarchivedGame)
  {
    DDLogError(@"%@: Restoring not possible, NSCoding archive not compatible", [self shortDescription]);
    NSFileManager* fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager removeItemAtPath:archiveFilePath error:nil];
    DDLogVerbose(@"%@: Removed archive file %@, result = %d", [self shortDescription], archiveFilePath, result);
    return false;
  }

  [self calculateZobristHashes:unarchivedGame];

  NewGameCommand* command = [[[NewGameCommand alloc] initWithGame:unarchivedGame] autorelease];
  // Computer player must not be triggered before the GTP engine has been
  // sync'ed (it is irrelevant that we are not going to trigger the computer
  // player at all)
  command.shouldTriggerComputerPlayer = false;
  [command submit];

  bool success = [[[[SyncGTPEngineCommand alloc] init] autorelease] submit];
  if (! success)
  {
    DDLogError(@"%@: Restoring not possible, cannot sync GTP engine", [self shortDescription]);
    return false;
  }

  if (GoGameTypeComputerVsComputer == unarchivedGame.type)
  {
    switch (unarchivedGame.state)
    {
      case GoGameStateGameIsPaused:
      case GoGameStateGameHasEnded:
      {
        break;
      }
      default:
      {
        DDLogWarn(@"%@: Computer vs. computer game is in state %d, i.e. not paused and not ended", [self shortDescription], unarchivedGame.state);
        [unarchivedGame pause];
        break;
      }
    }
  }

  // It is quite possible that the user suspended the app while the computer
  // was thinking (the "computer play" function makes this possible even in
  // human vs. human games) . We must reset that status here.
  if (unarchivedGame.isComputerThinking)
  {
    DDLogInfo(@"%@: Computer vs. computer game, turning off 'computer is thinking' state", [self shortDescription]);
    unarchivedGame.reasonForComputerIsThinking = GoGameComputerIsThinkingReasonIsNotThinking;
  }

  // The GTP engine always starts out with territory statistics disabled. The
  // following command enables/disables statistics according to the current
  // user preference.
  [[[[ToggleTerritoryStatisticsCommand alloc] init] autorelease] submit];

  // Observers that were created before the game was unarchived do not yet know
  // that scoring mode is enabled and that scoring information is available. We
  // tell GoScore to let them know. Note that we need to send two notifications
  // because some observers listen to one, some to the other notification, and
  // some may react to both in a different way. The fact that we cause
  // #goScoreCalculationEnds to be posted without a preceding
  // #goScoreCalculationStarts is well-known and documented.
  GoScore* unarchivedScore = unarchivedGame.score;
  if (unarchivedScore.scoringEnabled)
  {
    [unarchivedScore postScoringModeNotification];
    [unarchivedScore postScoringInProgressNotification];
  }

  return true;
}

// -----------------------------------------------------------------------------
/// Private helper
// -----------------------------------------------------------------------------
- (void) calculateZobristHashes:(GoGame*)unarchivedGame
{
  GoZobristTable* zobristTable = unarchivedGame.board.zobristTable;
  for (GoMove* move = unarchivedGame.firstMove; move != nil; move = move.next)
    move.zobristHash = [zobristTable hashForMove:move];
}

@end
