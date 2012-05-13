//
//  DLGraphController.m
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "DLGraphController.h"
#import <SM2DGraphView/SM2DGraphView.h>

#import "TimeSeries.h"
#import "ValueAtTime.h"

@implementation DLGraphController
- (void) awakeFromNib
{
	[graph setTitle:@"Current transformer 1"];
	[graph setDrawsGrid:YES];
	
	[graph setLabel:@"Current / A" forAxis:kSM2DGraph_Axis_Y];
	[graph setLabel:@"Seconds from first reading" forAxis:kSM2DGraph_Axis_X];
	
	[graph reloadData];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(managedObjectsChanged:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:[document managedObjectContext]];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:[document managedObjectContext]];
	[super dealloc];
}

- (void) managedObjectsChanged:(NSNotification *)notification
{
	NSLog(@"enter MOC");
	[graph refreshDisplay:self];
	NSLog(@"exit MOC");
}

- (NSUInteger)numberOfLinesInTwoDGraphView:(SM2DGraphView *)inGraphView {
	NSLog(@"enter numberOfLinesITDGV");
	NSManagedObjectContext *context = [document managedObjectContext];
	NSEntityDescription *description = [NSEntityDescription
										entityForName:@"TimeSeries" 
										inManagedObjectContext:context];
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:description];

	NSLog(@"exit numberOfLinesITDGV");
	return [context countForFetchRequest:request error:nil];
}

- (TimeSeries *) getSeries:(NSUInteger) index
{
	NSLog(@"enter getSeries");
	NSManagedObjectContext *context = [document managedObjectContext];
	NSEntityDescription *description = [NSEntityDescription
										entityForName:@"TimeSeries" inManagedObjectContext:context];
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:description];
	NSLog(@"get time series %d", index);
	TimeSeries *series = [[context executeFetchRequest:request error:nil] objectAtIndex:index];
	NSLog(@"exit getSeries");
	return series;
}

- (NSDate *)extremalDate:(BOOL)isMaximum fromSeries:(NSUInteger) index
{

	//	TimeSeries *series = [self getSeries:index];
	NSManagedObjectContext *context = [document managedObjectContext];
	NSEntityDescription *description = [NSEntityDescription
										entityForName:@"ValueAtTime" inManagedObjectContext:context];
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	//	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"container==%@",series];
	[request setEntity:description];	
	[request setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"time"
																					  ascending:!isMaximum] autorelease]]];
	//	[request setPredicate:predicate];
	
	[request setFetchLimit:1];
	
	return [[[context executeFetchRequest:request error:nil] objectAtIndex:0] time];
}



- (NSArray *)twoDGraphView:(SM2DGraphView *)inGraphView dataForLineIndex:(NSUInteger)inLineIndex {
	NSLog(@"current thread %@", [NSThread currentThread]);
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];
	
	//TimeSeries *series = [self getSeries:inLineIndex];
	NSManagedObjectContext *context = [document managedObjectContext];
	NSEntityDescription *description = [NSEntityDescription
										entityForName:@"ValueAtTime" inManagedObjectContext:context];
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	//	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"container==%@",series];
	[request setEntity:description];	
	[request setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"time"
																					  ascending:YES] autorelease]]];
	//[request setPredicate:predicate];
	
	NSDate *minimumDate = [self extremalDate:NO fromSeries:inLineIndex];
	double max_x = 0;
	double max_y = 0;
	NSArray *values = [context executeFetchRequest:request error:nil];
	for (int i = 0; i<[values count]; i++) {
		ValueAtTime *vat = [values objectAtIndex:i];
		[result addObject:NSStringFromPoint(NSMakePoint([[vat time] timeIntervalSinceDate:minimumDate], [[vat quantity] doubleValue]))];
		max_x = [[vat time] timeIntervalSinceDate:minimumDate];
		max_y = max_y > [[vat quantity] doubleValue] ? max_y : [[vat quantity] doubleValue];
	}
	
	[graph setNumberOfTickMarks:max_x / 60 forAxis:kSM2DGraph_Axis_X];
	[graph setNumberOfMinorTickMarks:60 forAxis:kSM2DGraph_Axis_X];
	[graph setNumberOfMinorTickMarks:10 forAxis:kSM2DGraph_Axis_Y];
	[graph setNumberOfTickMarks:(int) ceil(max_y)+1 forAxis:kSM2DGraph_Axis_Y];
	
	return result;
}

- (CGFloat)twoDGraphView:(SM2DGraphView *)inGraphView maximumValueForLineIndex:(NSUInteger)inLineIndex
				 forAxis:(SM2DGraphAxisEnum)inAxis 
{
	
	if (inAxis == kSM2DGraph_Axis_X) {
		
		NSDate *minimumDate = [self extremalDate:NO fromSeries:inLineIndex];
		NSDate *maximumDate = [self extremalDate:YES fromSeries:inLineIndex];
		return [maximumDate timeIntervalSinceDate:minimumDate];
	} else {
		//TimeSeries *series = [self getSeries:inLineIndex];
		NSManagedObjectContext *context = [document managedObjectContext];
		NSEntityDescription *description = [NSEntityDescription
											entityForName:@"ValueAtTime" inManagedObjectContext:context];
		
		NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
		//NSPredicate *predicate = [NSPredicate predicateWithFormat:@"container==%@",series];
		[request setEntity:description];		
		[request setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"quantity"
																						  ascending:NO] autorelease]]];
		//		[request setPredicate:predicate];
		
		[request setFetchLimit:1];
		return ceil([[[[context executeFetchRequest:request error:nil] objectAtIndex:0] quantity] doubleValue]);
	}
}

- (CGFloat)twoDGraphView:(SM2DGraphView *)inGraphView minimumValueForLineIndex:(NSUInteger)inLineIndex
				 forAxis:(SM2DGraphAxisEnum)inAxis 
{
	return 0.0;
}

@end
