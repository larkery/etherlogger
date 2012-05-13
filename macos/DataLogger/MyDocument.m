//
//  MyDocument.m
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright __MyCompanyName__ 2011 . All rights reserved.
//

#import "MyDocument.h"
#import "AMSerialPort.h"
#import "AMSerialPortList.h"
#import "TimeSeries.h"
#import "ValueAtTime.h"

@implementation MyDocument

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
    }
    return self;
}

- (NSString *)windowNibName 
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

- (IBAction) showDownloadSheet:(id)sender
{
	[serialPortList removeAllItems];
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *port;
	while (port = [enumerator nextObject]) {
		[serialPortList addItemWithTitle:[port bsdPath]];
	}
	
    [NSApp beginSheet:serialPortSheet modalForWindow:mainWindow
		modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (IBAction) hideDownloadSheet:(id)sender
{
	[serialPortSheet orderOut:nil];
	[NSApp endSheet:serialPortSheet];
	
	if (sender == connectButton) {
		NSString *deviceName = [serialPortList titleOfSelectedItem];
		AMSerialPort *port =
		[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDRS232Type)];
		
		

		
		NSFileHandle *handle = [port open];		
		partialLine = [[NSString alloc] init];
		
		if (handle) {

			[port setSpeed:115200];
			[port setParity:kAMSerialParityNone];
			[port setStopBits:kAMSerialStopBitsOne];
			[port commitChanges];
			
			[[NSNotificationCenter defaultCenter] 
			 addObserver:self 
			 selector:@selector(handleData:)
			 name:NSFileHandleDataAvailableNotification
			 object:handle];
			
			[handle waitForDataInBackgroundAndNotify];
		}
		
	}
}

- (void) addRecord:(int) deviceID v1:(float) current1 v2:(float) current2 v3:(float) current3 
{
	
		NSLog(@"current thread %@", [NSThread currentThread]);
	[amps setStringValue:[NSString stringWithFormat:@"%.1f A", current1]];
	[kilowatts setStringValue:[NSString stringWithFormat:@"%.2f kW", current1 * 0.24]];
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:@"HH:mm"];
	NSString *time = [formatter stringFromDate:[[[NSDate alloc] init] autorelease]];
	
	// get time series
	NSManagedObjectContext *context = [self managedObjectContext];
	NSPredicate *seriesPredicate = [NSPredicate predicateWithFormat:@"address = %@ AND index = %@", 
									[NSNumber numberWithInt:deviceID],
									[NSNumber numberWithInt:0]];
	
	NSEntityDescription *description = [NSEntityDescription
										entityForName:@"TimeSeries" inManagedObjectContext:context];
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:description];
	[request setPredicate:seriesPredicate];
	
	NSError *e;
	NSArray *serieses = [context executeFetchRequest:request error:&e];
	TimeSeries *series = nil;
	if ([serieses count] == 0) {
		series = [[TimeSeries alloc] initWithEntity:description insertIntoManagedObjectContext:context];
		[series setName:[NSString stringWithFormat:@"Series %d of sensor %d", 0, deviceID]];
		[series setAddress:[NSNumber numberWithInt:deviceID]];
		[series setIndex:[NSNumber numberWithInt:0]];
	} else {
		series = [serieses objectAtIndex:0];		
	}
	
	description = [NSEntityDescription entityForName:@"ValueAtTime" inManagedObjectContext:context];
	
	ValueAtTime *vat = [[ValueAtTime alloc] initWithEntity:description insertIntoManagedObjectContext:context];
	
	[vat setTime:[NSDate date]];
	[vat setQuantity:[NSNumber numberWithFloat:current1]];
	
	vat.container = series;
	
	[latestTime setStringValue:time];
	
}

- (void) handleData:(NSNotification *) notification
{
	NSLog(@"enter handleData");
	NSFileHandle *handle = [notification object];
	
	NSData *data = [handle availableData];
	if ([data length] == 0) {
		NSLog(@"not sure about this");
			[handle waitForDataInBackgroundAndNotify];
		return; //hmm
	}
	
	NSString *extra = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
	if (extra == nil) {
		NSLog(@"extra is nil! %@", data);
					[handle waitForDataInBackgroundAndNotify];
		return;
	}
	NSString *buffer = [partialLine stringByAppendingString:extra];
	
	NSArray *lines = [buffer componentsSeparatedByString:@"\n"];
	NSInteger lcm1 = [lines count] - 1;
	for (int i = 0; i<lcm1; i++) {
		NSLog(@"record: %@", [lines objectAtIndex:i]);
		NSArray *fields = [[lines objectAtIndex:i] componentsSeparatedByString:@","];
		if ([fields count] == 4) {
			[self addRecord:[[fields objectAtIndex:0] intValue]
			 v1:[[fields objectAtIndex:1] floatValue]
			 			 v2:[[fields objectAtIndex:2] floatValue]
			 v3:[[fields objectAtIndex:3] floatValue]];
		}
	}
	

	NSString *x = [[lines lastObject] retain];
	[partialLine release];
	partialLine = x;
	
	[handle waitForDataInBackgroundAndNotify];
	NSLog(@"exit handleData");
}

- (IBAction) dbgMakePoint:(id)sender {
	[self addRecord:94 v1:(rand() / (double) RAND_MAX) v2:0 v3:0];
}

@end
