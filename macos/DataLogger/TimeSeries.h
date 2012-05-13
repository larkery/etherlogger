//
//  TimeSeries.h
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class ValueAtTime;

@interface TimeSeries :  NSManagedObject  
{
}

@property (nonatomic, retain) NSNumber * address;
@property (nonatomic, retain) NSNumber * index;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet* values;

@end


@interface TimeSeries (CoreDataGeneratedAccessors)
- (void)addValuesObject:(ValueAtTime *)value;
- (void)removeValuesObject:(ValueAtTime *)value;
- (void)addValues:(NSSet *)value;
- (void)removeValues:(NSSet *)value;

@end

