//
//  DLGraphController.h
//  DataLogger
//
//  Created by Tom Hinton on 16/03/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MyDocument;
@class SM2DGraphView;

@interface DLGraphController : NSObject {
	IBOutlet MyDocument* document;
	IBOutlet SM2DGraphView *graph;
}

@end
