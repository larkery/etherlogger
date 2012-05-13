//
//  MyDocument.h
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright __MyCompanyName__ 2011 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SM2DGraphView/SM2DGraphView.h>

@interface MyDocument : NSPersistentDocument {
	IBOutlet NSPopUpButton *serialPortList;
	IBOutlet NSTextField *amps;
	IBOutlet NSTextField *kilowatts;
	IBOutlet NSTextField *latestTime;
	IBOutlet SM2DGraphView *graph;
	
	
	IBOutlet NSWindow *mainWindow;
	IBOutlet NSPanel *serialPortSheet;
	IBOutlet NSButton *connectButton;
	NSString *partialLine;
}

- (IBAction) showDownloadSheet:(id)sender;
- (IBAction) hideDownloadSheet:(id)sender;

- (IBAction) dbgMakePoint:(id)sender;

@end
