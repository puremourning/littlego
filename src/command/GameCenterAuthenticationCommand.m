//
//  GameCenterAuthenticationCommand.m
//  Little Go
//
//  Created by Ben Jackson on 07/02/2015.
//
//

#import "GameCenterAuthenticationCommand.h"

#import "../main/ApplicationDelegate.h"
#import "MainTabBarController.h"

@interface GameCenterAuthenticationCommand()
@property(nonatomic, retain, readwrite) UIViewController* loginViewController;
@end

@implementation GameCenterAuthenticationCommand
@synthesize asynchronousCommandDelegate;

// -----------------------------------------------------------------------------
/// @brief Initializes a GameCenterAuthenticationCommand object.
///
/// @note This is the designated initializer of GameCenterAuthenticationCommand.
// -----------------------------------------------------------------------------
- (id) initWithLoginViewController:(UIViewController*) viewController
{
  // Call designated initializer of superclass (CommandBase)
  self = [super init];
  if (! self)
    return nil;
  
  self.loginViewController = viewController;
  
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this GameCenterAuthenticationCommand object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.loginViewController = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  [self performSelectorOnMainThread:@selector(doItInMainThread)
                         withObject:nil
                      waitUntilDone:YES];
  
  return true;
}

-(void) doItInMainThread
{
  [[ApplicationDelegate sharedDelegate].windowRootViewController
        presentViewController:self.loginViewController
                     animated:YES
                   completion:nil];
}

@end
