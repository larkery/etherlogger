//
//  ValueAtTime.h
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class TimeSeries;

@interface ValueAtTime :  NSManagedObject  
{
}

@property (nonatomic, retain) NSDate * time;
@property (nonatomic, retain) NSNumber * quantity;
@property (nonatomic, retain) TimeSeries * container;

@end



