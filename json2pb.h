//
//  json2pb.h
//  xcaller
//
//  Created by rannger on 2017/8/30.
//  Copyright © 2017年 yy. All rights reserved.
//

#import <Foundation/Foundation.h>

#if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
#import <Protobuf/GPBProtocolBuffers_RuntimeSupport.h>
#else
#import "GPBProtocolBuffers_RuntimeSupport.h"
#endif

@interface GPBMessage (JSON)
+ (void)fromJson:(GPBMessage*)msg data:(NSData*)data keyMap:(NSDictionary*)map;
+ (NSString*)toJson:(GPBMessage*)msg keyMap:(NSDictionary*)map;

- (id)initWithJson:(NSData*)data;
- (NSString*)toJson;
@end
