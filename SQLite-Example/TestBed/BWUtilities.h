//  BWUtilities.h
//  Copyright 2010-2014 The BearHeart Group, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString * const kBWUtilitiesVersion = @"1.1.1";
static NSString * const kAlertTitle = @"BW Testbed";
static BOOL const kMessageActive = YES;

// populated from loadDidView
extern UITextView * messageTextView;

void message ( NSString *format, ... );
void alertMessage ( NSString *format, ... );
NSString * flattenHTML ( NSString * html );
NSString * trimString ( NSString * string );
