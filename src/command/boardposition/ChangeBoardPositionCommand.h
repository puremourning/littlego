// -----------------------------------------------------------------------------
// Copyright 2013 Patrick Näf (herzbube@herzbube.ch)
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
#import "CommandBase.h"


// -----------------------------------------------------------------------------
/// @brief The ChangeBoardPositionCommand class is responsible for changing the
/// current board position to a new value.
///
/// initWithBoardPosition:() must be invoked with a valid board position,
/// otherwise command execution will fail.
///
/// initWithOffset:() is more permissive and can be invoked with an offset that
/// would result in an invalid board position (i.e. a position before the first,
/// or after the last position of the game). Such an offset is adjusted so that
/// the result is a valid board position (i.e. either the first or the last
/// board position of the game).
///
/// After it has changed the board position, ChangeBoardPositionCommand performs
/// the following additional operations:
/// - Synchronizes the GTP engine with the new board position
/// - Recalculates the score for the new board position if scoring mode is
///   currently enabled
// -----------------------------------------------------------------------------
@interface ChangeBoardPositionCommand : CommandBase
{
}

- (id) initWithBoardPosition:(int)boardPosition;
- (id) initWithFirstBoardPosition;
- (id) initWithLastBoardPosition;
- (id) initWithOffset:(int)offset;

@end