//
//  GameCenterAuthenticationCommand.h
//  Little Go
//
//  Created by Ben Jackson on 07/02/2015.
//
//

#import "CommandBase.h"
#import "AsynchronousCommand.h"

// Forward declarations
@class UIViewController;

@interface GameCenterAuthenticationCommand : CommandBase<AsynchronousCommand>
{
}

- (id) initWithLoginViewController:(UIViewController*)viewController;

@end
