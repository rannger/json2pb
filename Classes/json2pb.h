//
//  json2pb.h
//  xcaller
//
//  Created by rannger on 2017/8/30.
//  Copyright © 2017年 rannger. All rights reserved.
//

#import <Protobuf/GPBMessage.h>

@interface GPBMessage (JSON)
+ (void)fromJson:(GPBMessage*)msg data:(NSData*)data keyMap:(NSDictionary*)map;
+ (NSString*)toJson:(GPBMessage*)msg keyMap:(NSDictionary*)map;

- (id)initWithJson:(NSData*)data;
- (NSString*)toJson;
@end
