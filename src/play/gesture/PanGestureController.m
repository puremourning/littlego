// -----------------------------------------------------------------------------
// Copyright 2013-2015 Patrick Näf (herzbube@herzbube.ch)
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
#import "PanGestureController.h"
#import "../boardview/BoardView.h"
#import "../gameaction/GameActionManager.h"
#import "../model/BoardViewMetrics.h"
#import "../model/BoardViewModel.h"
#import "../../go/GoBoardPosition.h"
#import "../../go/GoGame.h"
#import "../../go/GoScore.h"
#import "../../main/ApplicationDelegate.h"
#import "../../main/MainUtility.h"
#import "../../main/MagnifyingGlassOwner.h"
#import "../../utility/ExceptionUtility.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for PanGestureController.
// -----------------------------------------------------------------------------
@interface PanGestureController()
@property(nonatomic, retain) UILongPressGestureRecognizer* longPressRecognizer;
@property(nonatomic, assign, getter=isPanningEnabled) bool panningEnabled;
@end


@implementation PanGestureController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a PanGestureController object.
///
/// @note This is the designated initializer of PanGestureController.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;
  self.boardView = nil;
  [self setupLongPressGestureRecognizer];
  [self setupNotificationResponders];
  [self updatePanningEnabled];
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PanGestureController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[GoGame sharedGame].boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];
  self.boardView = nil;
  self.longPressRecognizer = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializer.
// -----------------------------------------------------------------------------
- (void) setupLongPressGestureRecognizer
{
  self.longPressRecognizer = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)] autorelease];
  self.longPressRecognizer.delegate = self;
  CGFloat infiniteMovement = CGFLOAT_MAX;
  self.longPressRecognizer.allowableMovement = infiniteMovement;  // let the user pan as long as he wants
  self.longPressRecognizer.minimumPressDuration = gGoBoardLongPressDelay;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializer.
// -----------------------------------------------------------------------------
- (void) setupNotificationResponders
{
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameWillCreate:) name:goGameWillCreate object:nil];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(goGameStateChanged:) name:goGameStateChanged object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStarts object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStops object:nil];
  [center addObserver:self selector:@selector(goScoreScoringEnabled:) name:goScoreScoringEnabled object:nil];
  [center addObserver:self selector:@selector(goScoreScoringDisabled:) name:goScoreScoringDisabled object:nil];
  // KVO observing
  [[GoGame sharedGame].boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];
}

#pragma mark - Property setter

// -----------------------------------------------------------------------------
/// @brief Private setter implementation.
// -----------------------------------------------------------------------------
- (void) setBoardView:(BoardView*)boardView
{
  if (_boardView == boardView)
    return;
  if (_boardView && self.longPressRecognizer)
    [_boardView removeGestureRecognizer:self.longPressRecognizer];
  _boardView = boardView;
  if (_boardView && self.longPressRecognizer)
    [_boardView addGestureRecognizer:self.longPressRecognizer];
}

#pragma mark - UIGestureRecognizerDelegate overrides

// -----------------------------------------------------------------------------
/// @brief UIGestureRecognizerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) handlePanFrom:(UILongPressGestureRecognizer*)gestureRecognizer
{
  // TODO move the following summary somewhere else where it is not buried in
  // code and forgotten...
  // 1. Touching the screen starts stone placement
  // 2. Stone is placed when finger leaves the screen and the stone is placed
  //    in a valid location
  // 3. Stone placement can be cancelled by placing in an invalid location
  // 4. Invalid locations are: Another stone is already placed on the point;
  //    placing the stone would be suicide; the point is guarded by a Ko; the
  //    point is outside the board; the point is not on the visible area of the
  //    board (if the board is zoomed)
  // 5. While panning/dragging, provide continuous feedback on the current
  //    stone location
  //    - Display a stone of the correct color at the current location
  //    - Mark up the stone differently from already placed stones
  //    - Mark up the stone differently if it is in a valid location, and if
  //      it is in an invalid location
  //    - Display in the status line the vertex of the current location
  //    - If the location is invalid, display the reason in the status line
  //    - If placing a stone would capture other stones, mark up those stones
  //      and display in the status line how many stones would be captured
  //    - If placing a stone would set a group (your own or an enemy group) to
  //      atari, mark up that group
  // 6. Place the stone with an offset to the fingertip position so that the
  //    user can see the stone location

  CGPoint panningLocation = [gestureRecognizer locationInView:self.boardView];
  BoardViewIntersection crossHairIntersection = [self.boardView crossHairIntersectionNear:panningLocation];

  bool isLegalMove = false;
  enum GoMoveIsIllegalReason illegalReason = GoMoveIsIllegalReasonUnknown;
  if (! BoardViewIntersectionIsNullIntersection(crossHairIntersection))
  {
    CGRect visibleRect = self.boardView.bounds;
    // Don't use panningLocation for this check because the cross-hair might
    // be offset due to the user preference "stoneDistanceFromFingertip"
    bool isCrossHairInVisibleRect = CGRectContainsPoint(visibleRect, crossHairIntersection.coordinates);
    if (isCrossHairInVisibleRect)
      isLegalMove = [[GoGame sharedGame] isLegalMove:crossHairIntersection.point isIllegalReason:&illegalReason];
    else
      crossHairIntersection = BoardViewIntersectionNull;
  }

  BoardViewModel* boardViewModel = [ApplicationDelegate sharedDelegate].boardViewModel;
  UIGestureRecognizerState recognizerState = gestureRecognizer.state;
  switch (recognizerState)
  {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateChanged:
    {
      if (UIGestureRecognizerStateBegan == recognizerState)
      {
        boardViewModel.boardViewDisplaysCrossHair = true;
        [[NSNotificationCenter defaultCenter] postNotificationName:boardViewWillDisplayCrossHair object:nil];
      }

      [self.boardView moveCrossHairTo:crossHairIntersection.point isLegalMove:isLegalMove isIllegalReason:illegalReason];
      NSArray* crossHairInformation;
      if (crossHairIntersection.point)
      {
        crossHairInformation = [[[NSArray alloc] initWithObjects:
                                 crossHairIntersection.point,
                                 [NSNumber numberWithBool:isLegalMove],
                                 [NSNumber numberWithInt:illegalReason],
                                 nil] autorelease];
      }
      else
      {
        crossHairInformation = [NSArray array];
      }
      [[NSNotificationCenter defaultCenter] postNotificationName:boardViewDidChangeCrossHair object:crossHairInformation];
      break;
    }
    case UIGestureRecognizerStateEnded:
    {
      boardViewModel.boardViewDisplaysCrossHair = false;
      [[NSNotificationCenter defaultCenter] postNotificationName:boardViewWillHideCrossHair object:nil];
      [self.boardView moveCrossHairTo:nil isLegalMove:true isIllegalReason:illegalReason];
      [[NSNotificationCenter defaultCenter] postNotificationName:boardViewDidChangeCrossHair object:[NSArray array]];
      if (isLegalMove)
        [[GameActionManager sharedGameActionManager] playAtIntersection:crossHairIntersection.point];
      break;
    }
    // Occurs, for instance, if an alert is displayed while a gesture is
    // being handled, or if the gesture recognizer was disabled.
    case UIGestureRecognizerStateCancelled:
    {
      boardViewModel.boardViewDisplaysCrossHair = false;
      [[NSNotificationCenter defaultCenter] postNotificationName:boardViewWillHideCrossHair object:nil];
      [self.boardView moveCrossHairTo:nil isLegalMove:true isIllegalReason:illegalReason];
      [[NSNotificationCenter defaultCenter] postNotificationName:boardViewDidChangeCrossHair object:[NSArray array]];
      break;
    }
    default:
    {
      break;
    }
  }

  // Perform magnifying glass handling only after the Go board graphics changes
  // have been queued
  [self handleMagnifyingGlassForPanningLocation:panningLocation
                          crossHairIntersection:crossHairIntersection];
}

// -----------------------------------------------------------------------------
/// @brief UIGestureRecognizerDelegate protocol method.
// -----------------------------------------------------------------------------
- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer
{
  return (self.isPanningEnabled ? YES : NO);
}

#pragma mark - Notification responders

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameWillCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameWillCreate:(NSNotification*)notification
{
  GoGame* oldGame = [notification object];
  [oldGame.boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  GoGame* newGame = [notification object];
  [newGame.boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameStateChanged notification.
// -----------------------------------------------------------------------------
- (void) goGameStateChanged:(NSNotification*)notification
{
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #computerPlayerThinkingStarts and
/// #computerPlayerThinkingStops notifications.
// -----------------------------------------------------------------------------
- (void) computerPlayerThinkingChanged:(NSNotification*)notification
{
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringEnabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringEnabled:(NSNotification*)notification
{
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringDisabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringDisabled:(NSNotification*)notification
{
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if (object == [GoGame sharedGame].boardPosition)
  {
    [self cancelPanningInProgress];
    [self updatePanningEnabled];
  }
}

#pragma mark - Updaters

// -----------------------------------------------------------------------------
/// @brief Updates whether panning is enabled.
// -----------------------------------------------------------------------------
- (void) updatePanningEnabled
{
  GoGame* game = [GoGame sharedGame];
  if (! game)
  {
    self.panningEnabled = false;
    return;
  }
  GoBoardPosition* boardPosition = game.boardPosition;

  if (game.score.scoringEnabled)
  {
    self.panningEnabled = false;
    return;
  }

  if (GoGameTypeComputerVsComputer == game.type)
  {
    self.panningEnabled = false;
    return;
  }

  if (GoGameStateGameHasEnded == game.state)
  {
    if (boardPosition.isLastPosition)
    {
      self.panningEnabled = false;
      return;
    }
  }

  // We get here in two cases
  // 1) The game is still in progress
  // 2) The game has ended, but the user is viewing an old board position
  if (game.isComputerThinking)
  {
    self.panningEnabled = false;
  }
  else
  {
    GoBoardPosition* boardPosition = [GoGame sharedGame].boardPosition;
    if (boardPosition.isComputerPlayersTurn)
      self.panningEnabled = false;
    else
      self.panningEnabled = true;
  }
}

#pragma mark - Magnifying glass handling

// -----------------------------------------------------------------------------
/// @brief Performs magnifying glass handling according to the current user
/// defaults. If the magnifying glass is enabled, the center of magnification is
/// either at @a panningLocation or at the coordinate represented by
/// @a crossHairIntersection
// -----------------------------------------------------------------------------
- (void) handleMagnifyingGlassForPanningLocation:(CGPoint)panningLocation
                           crossHairIntersection:(BoardViewIntersection)crossHairIntersection
{
  BoardViewModel* boardViewModel = [ApplicationDelegate sharedDelegate].boardViewModel;
  switch (boardViewModel.magnifyingGlassEnableMode)
  {
    case MagnifyingGlassEnableModeAlwaysOn:
      break;
    case MagnifyingGlassEnableModeAlwaysOff:
      return;
    case MagnifyingGlassEnableModeAuto:
      if ([ApplicationDelegate sharedDelegate].boardViewMetrics.cellWidth >= gridCellSizeThresholdForAutoMagnifyingGlass)
        return;
      break;
    default:
      [ExceptionUtility throwNotImplementedException];
      break;
  }

  switch (boardViewModel.magnifyingGlassUpdateMode)
  {
    case MagnifyingGlassUpdateModeSmooth:
      if (boardViewModel.boardViewDisplaysCrossHair)
        [self updateMagnifyingGlassForPanningLocation:panningLocation];
      else
        [self disableMagnifyingGlass];
      break;
    case MagnifyingGlassUpdateModeCrossHair:
      if (BoardViewIntersectionIsNullIntersection(crossHairIntersection))
        [self disableMagnifyingGlass];
      else
        [self updateMagnifyingGlassForCrossHairIntersection:crossHairIntersection];
    default:
      [ExceptionUtility throwNotImplementedException];
      break;
  }
}

// -----------------------------------------------------------------------------
/// @brief Enables the magnifying glass if it is not currently enabled, then
/// updates the magnifying glass so that it displays the content around the
/// center of magnification that is equal to @a panningLocation.
// -----------------------------------------------------------------------------
- (void) updateMagnifyingGlassForPanningLocation:(CGPoint)panningLocation
{
  id<MagnifyingGlassOwner> magnifyingGlassOwner = [MainUtility magnifyingGlassOwner];
  magnifyingGlassOwner.magnifyingGlassEnabled = true;
  MagnifyingViewController* magnifyingViewController = magnifyingGlassOwner.magnifyingViewController;
  [magnifyingViewController updateMagnificationCenter:panningLocation inView:self.boardView];
}

// -----------------------------------------------------------------------------
/// @brief Enables the magnifying glass if it is not currently enabled, then
/// updates the magnifying glass so that it displays the content around the
/// center of magnification that is at the coordinate represented by
/// @a crossHairIntersection.
// -----------------------------------------------------------------------------
- (void) updateMagnifyingGlassForCrossHairIntersection:(BoardViewIntersection)crossHairIntersection
{
  id<MagnifyingGlassOwner> magnifyingGlassOwner = [MainUtility magnifyingGlassOwner];
  magnifyingGlassOwner.magnifyingGlassEnabled = true;
  MagnifyingViewController* magnifyingViewController = magnifyingGlassOwner.magnifyingViewController;
  BoardViewMetrics* metrics = [ApplicationDelegate sharedDelegate].boardViewMetrics;
  CGPoint magnificationCenter = [metrics coordinatesFromPoint:crossHairIntersection.point];
  [magnifyingViewController updateMagnificationCenter:magnificationCenter inView:self.boardView];
}

// -----------------------------------------------------------------------------
/// @brief Disables (= hides) the magnifying glass.
// -----------------------------------------------------------------------------
- (void) disableMagnifyingGlass
{
  id<MagnifyingGlassOwner> magnifyingGlassOwner = [MainUtility magnifyingGlassOwner];
  magnifyingGlassOwner.magnifyingGlassEnabled = false;
}

#pragma mark - MagnifyingViewControllerDelegate overrides

// -----------------------------------------------------------------------------
/// @brief MagnifyingViewControllerDelegate protocol method.
// -----------------------------------------------------------------------------
- (enum MagnifyingGlassVeerDirection) magnifyingViewControllerVeerDirection:(MagnifyingViewController*)magnifyingViewController
{
  BoardViewModel* boardViewModel = [ApplicationDelegate sharedDelegate].boardViewModel;
  return boardViewModel.magnifyingGlassVeerDirection;
}

#pragma mark - Private helpers

// -----------------------------------------------------------------------------
/// @brief Cancels a panning gesture that is currently in progress.
// -----------------------------------------------------------------------------
- (void) cancelPanningInProgress
{
  self.longPressRecognizer.enabled = NO;
  self.longPressRecognizer.enabled = YES;
}

@end
