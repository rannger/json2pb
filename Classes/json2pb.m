//
//  json2pb.m
//  xcaller
//
//  Created by rannger on 2017/8/30.
//  Copyright © 2017年 rannger. All rights reserved.
//

#import "json2pb.h"
#import <Protobuf/GPBProtocolBuffers_RuntimeSupport.h>

static inline NSNumber* json_real(double value) { return [NSNumber numberWithDouble:value]; }
static inline NSNumber* json_integer(int64_t value) { return [NSNumber numberWithLongLong:value]; }
static inline NSNumber* json_boolean(bool value) { return [NSNumber numberWithBool:value]; }
static id<NSObject> pb2jsonInternal(GPBMessage* msg);
static id<NSObject> field2json(GPBMessage* msg, GPBFieldDescriptor *field, size_t index)
{
    BOOL repeated = ([field fieldType] == GPBFieldTypeRepeated);
    id<NSObject> jf = NULL;

    switch ([field dataType]) {
#define __CASE(type, ctype, fmt, arraytype, sfunc)                             \
  case type: {                                                                 \
    ctype value;                                                               \
    if (repeated) {                                                            \
      arraytype *array = GPBGetMessageRepeatedField(msg, field);               \
      value = [array valueAtIndex:index];                                      \
    } else {                                                                   \
      value = sfunc(msg, field);                                               \
    }                                                                          \
    jf = fmt(value);                                                           \
    break;                                                                     \
  }

            __CASE(GPBDataTypeDouble, double, json_real,GPBDoubleArray,GPBGetMessageDoubleField);
            __CASE(GPBDataTypeFloat, double, json_real,GPBFloatArray,GPBGetMessageFloatField);
            __CASE(GPBDataTypeInt64, uint64_t, json_integer,GPBInt64Array,GPBGetMessageInt64Field);
            __CASE(GPBDataTypeSFixed64, uint64_t, json_integer,GPBInt64Array,GPBGetMessageInt64Field);
            __CASE(GPBDataTypeSInt64, uint64_t, json_integer,GPBInt64Array,GPBGetMessageInt64Field);
            __CASE(GPBDataTypeUInt64, uint64_t, json_integer,GPBUInt64Array,GPBGetMessageUInt64Field);
            __CASE(GPBDataTypeFixed64, uint64_t, json_integer,GPBUInt64Array,GPBGetMessageUInt64Field);
            __CASE(GPBDataTypeInt32, uint64_t, json_integer,GPBInt32Array,GPBGetMessageInt32Field);
            __CASE(GPBDataTypeSInt32, uint64_t, json_integer,GPBInt32Array,GPBGetMessageInt32Field);
            __CASE(GPBDataTypeSFixed32, uint64_t, json_integer,GPBInt32Array,GPBGetMessageInt32Field);
            __CASE(GPBDataTypeUInt32, uint64_t, json_integer,GPBUInt32Array,GPBGetMessageUInt32Field);
            __CASE(GPBDataTypeFixed32, uint64_t, json_integer,GPBUInt32Array,GPBGetMessageUInt32Field);
            __CASE(GPBDataTypeBool, bool, json_boolean,GPBBoolArray,GPBGetMessageBoolField);
#undef __CASE
        case GPBDataTypeString:
        {
            NSString* value = nil;
            if (repeated) {
                NSArray<NSString*>* array = GPBGetMessageRepeatedField(msg,field);
                value = array[index];
            } else {
                value = GPBGetMessageStringField(msg, field);
            }
            
            jf = [NSString stringWithString:value];
        }
            break;
        case GPBDataTypeBytes:
        {
            NSData* data = nil;
            if (repeated) {
                NSArray<NSData*>* array = GPBGetMessageRepeatedField(msg,field);
                data = array[index];
            } else {
                data = GPBGetMessageBytesField(msg,field);
            }
            data = [data base64EncodedDataWithOptions:NSDataBase64Encoding64CharacterLineLength];
            jf =  [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
            break;
        case GPBDataTypeMessage:
        {
            GPBMessage* mesg = nil;
            if (repeated) {
                NSArray<GPBMessage*>* array = GPBGetMessageRepeatedField(msg, field);
                mesg = array[index];
            } else {
                mesg = GPBGetMessageMessageField(msg, field);
            }
            
            jf = pb2jsonInternal(mesg);
        }
            break;
        case GPBDataTypeEnum:
        {
            int32_t value = 0;
            if (repeated) {
                GPBEnumArray* array = GPBGetMessageRepeatedField(msg, field);
                value = [array valueAtIndex:index];
            } else {
                value = GPBGetMessageEnumField(msg, field);
            }
            jf = json_integer(value);
        }
            break;
        default:
            break;
    }
    
    return jf;
}

static id<NSObject> pb2jsonInternal(GPBMessage* msg)
{
    GPBDescriptor* d = [msg descriptor];
    NSMutableDictionary* root = [NSMutableDictionary dictionaryWithCapacity:10];
    
    for (GPBFieldDescriptor* field in [d fields]) {
        id<NSObject> jf = nil;
        if ([field fieldType] == GPBFieldTypeRepeated) {
            NSArray* array = GPBGetMessageRepeatedField(msg, field);
            if ([array respondsToSelector:@selector(count)]&& [array count]!=0) {
                NSMutableArray* list = [NSMutableArray arrayWithCapacity:[array count]];
                for (int i = 0; i<[array count]; ++i) {
                    id<NSObject> res = field2json(msg, field, i);
                    if (nil!=res) {
                        [list addObject:res];
                    }
                }
                jf = list;
            }
        } else if (GPBGetHasIvarField(msg, field)) {
            jf = field2json(msg, field, 0);
        } else {
            continue;
        }
        NSString* name = [field textFormatName];
        if (nil==jf)
            continue;
        [root setObject:jf forKey:name];
    }
    
    return root;
}

static void json2pbInternal(GPBMessage* msg, id<NSObject> root);
static void json2fieldInternal(GPBMessage* msg, GPBFieldDescriptor* field, id<NSObject> jf)
{
    BOOL repeated = ([field fieldType] == GPBFieldTypeRepeated);
    switch ([field dataType]) {

#define __SET_OR_ADD(sfunc, value, arraytype)                                  \
  do {                                                                         \
    if (repeated) {                                                            \
      arraytype *array = GPBGetMessageRepeatedField(msg, field);               \
      if ([array respondsToSelector:@selector(addValue:)]) {                   \
        [array addValue:value];                                                \
      } else {                                                                 \
        assert(0);                                                             \
      }                                                                        \
    } else {                                                                   \
      sfunc(msg, field, value);                                                \
    }                                                                          \
  } while (0);
#define __CASE(type, ctype, fmt, arraytype, sfunc)                             \
  case type: {                                                                 \
    NSNumber* js = (NSNumber*)jf;                                              \
    ctype value = [js fmt];                                                    \
    __SET_OR_ADD(sfunc, value, arraytype);                                     \
    break;                                                                     \
  }
            
            __CASE(GPBDataTypeDouble, double, doubleValue,GPBDoubleArray,GPBSetMessageDoubleField);
            __CASE(GPBDataTypeFloat, double, doubleValue,GPBFloatArray,GPBSetMessageFloatField);
            __CASE(GPBDataTypeInt64, int64_t,longLongValue, GPBInt64Array,GPBSetMessageInt64Field);
            
            __CASE(GPBDataTypeSFixed64,int64_t, longLongValue, GPBInt64Array,GPBSetMessageInt64Field);
            __CASE(GPBDataTypeSInt64,int64_t, longLongValue, GPBInt64Array,GPBSetMessageInt64Field);
            __CASE(GPBDataTypeUInt64,int64_t, longLongValue, GPBUInt64Array,GPBSetMessageUInt64Field);
            __CASE(GPBDataTypeFixed64,int64_t, longLongValue, GPBUInt64Array,GPBSetMessageUInt64Field);
            __CASE(GPBDataTypeInt32,int64_t, longLongValue, GPBInt32Array,GPBSetMessageInt32Field);
            __CASE(GPBDataTypeSInt32,int64_t, longLongValue, GPBInt32Array,GPBSetMessageInt32Field);
            __CASE(GPBDataTypeSFixed32,int64_t, longLongValue, GPBInt32Array,GPBSetMessageInt32Field);
            __CASE(GPBDataTypeUInt32,int64_t, longLongValue, GPBUInt32Array,GPBSetMessageUInt32Field);
            __CASE(GPBDataTypeFixed32,int64_t, longLongValue, GPBUInt32Array,GPBSetMessageUInt32Field);
            __CASE(GPBDataTypeBool, BOOL, boolValue,GPBBoolArray,GPBSetMessageBoolField);
#undef __SET_OR_ADD
#undef __CASE

#define __SET_OR_ADD(sfunc, value, arraytype)                                  \
  do {                                                                         \
    if (repeated) {                                                            \
      arraytype *array = GPBGetMessageRepeatedField(msg, field);               \
      if ([array respondsToSelector:@selector(addObject:)]) {                  \
        [array addObject:value];                                               \
      } else {                                                                 \
        assert(0);                                                             \
      }                                                                        \
    } else {                                                                   \
      sfunc(msg, field, value);                                                \
    }                                                                          \
  } while (0);

        case GPBDataTypeString:
        {
            if (![jf isKindOfClass:[NSString class]]) {
                [NSException exceptionWithName:@"Not a string" reason:@"Not a string" userInfo:nil];
            }
            NSString* string = (NSString*)jf;
            __SET_OR_ADD(GPBSetMessageStringField, string, NSMutableArray);
        }
            break;
        case GPBDataTypeBytes:
        {
            if (![jf isKindOfClass:[NSString class]]) {
                [NSException exceptionWithName:@"Not a string" reason:@"Not a string" userInfo:nil];
            }
            NSString* string = (NSString*)jf;
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:string options:0];
            __SET_OR_ADD(GPBSetMessageBytesField, decodedData, NSMutableArray);
        }
            break;
        case GPBDataTypeMessage:
        {
            GPBMessage* mf = nil;
            if (repeated) {
                mf = [[field.msgClass alloc] init];
            } else {
                mf = GPBGetMessageMessageField(msg, field);
            }
            json2pbInternal(mf, jf);
            if (repeated) {
                NSMutableArray* array = GPBGetMessageRepeatedField(msg, field);
                [array addObject:mf];
            }
        }
            break;
        case GPBDataTypeEnum:
        {
            GPBEnumDescriptor* ed = field.enumDescriptor;
            int32_t value = 0;
            if ([jf isKindOfClass:[NSNumber class]]) {
                NSNumber* js = (NSNumber*)jf;
                value = [js intValue];
            } else if ([jf isKindOfClass:[NSString class]]) {
                
                BOOL ret = [ed getValue:&value
                            forEnumTextFormatName:(NSString*)jf];
                assert(ret);
            } else {
                 [NSException exceptionWithName:@"Not an integer or string"
                                         reason:@"Not an integer or string"
                                       userInfo:nil];
            }
            if (repeated) {
                GPBEnumArray* array = GPBGetMessageRepeatedField(msg, field);
                [array addRawValue:value];
            } else {
                GPBSetMessageEnumField(msg, field,value);
            }
        }
            break;
        default:
            break;
    }
}

static void json2pbInternal(GPBMessage* msg, id<NSObject> root)
{
    GPBDescriptor* d = [msg descriptor];
    if (!d)
        [NSException exceptionWithName:@"No descriptor or reflection"
                                reason:@"No descriptor or reflection"
                              userInfo:nil];

    for (NSString* name in [(NSDictionary*)root allKeys]) {
        id<NSObject> jf = [(NSDictionary*)root objectForKey:name];

        GPBFieldDescriptor* field = [d fieldWithName:name];
        if (!field) {
            for (GPBFieldDescriptor* f in [d fields]) {
                if ([[f textFormatName] isEqualToString:name]) {
                    field = f;
                    break;
                }
            }
        }
        
        if (!field) {
            [NSException exceptionWithName:@"No descriptor or reflection"
                                    reason:@"No descriptor or reflection" userInfo:nil];
        }
        
        if ([field fieldType] == GPBFieldTypeRepeated) {
            if (![jf isKindOfClass:[NSArray class]])
                [NSException exceptionWithName:@"Not array" reason:@"Not array" userInfo:nil];
            for (NSInteger j = 0; j<[(NSArray*)jf count]; ++j) {
                json2fieldInternal(msg, field, [(NSArray*)jf objectAtIndex:j]);
            }
        } else {
            json2fieldInternal(msg, field, jf);
        }
    }
}

static int jsonDumpString(const char *buf, size_t size, void *data)
{
    NSMutableString *s = (__bridge NSMutableString *) data;
    NSString* string = [[NSString alloc] initWithBytes:buf length:size encoding:NSUTF8StringEncoding];
    [s appendString:string];
    return 0;
}

@implementation GPBMessage (JSON)

+ (void)fromJson:(GPBMessage*)msg data:(NSData*)data
{
    NSError* error = nil;
    id<NSObject> root = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if (nil!=error)
        [NSException exceptionWithName:@"Load failed"
                                reason:error.description
                              userInfo:nil];

    json2pbInternal(msg, root);
}

+ (NSString*)toJson:(GPBMessage*)msg
{
    id<NSObject> root = pb2jsonInternal(msg);
    NSAssert([NSJSONSerialization isValidJSONObject:root], @"");
    NSData* data = [NSJSONSerialization dataWithJSONObject:root options:kNilOptions error:nil];
    NSString* r = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return r;
}

- (id)initWithJson:(NSData*)data
{
    self = [self init];
    if (self) {
        [GPBMessage fromJson:self data:data];
    }
    
    return self;
}

- (NSString*)toJson
{
    return [GPBMessage toJson:self];
}

@end

