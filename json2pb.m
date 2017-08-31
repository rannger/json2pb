//
//  json2pb.m
//  xcaller
//
//  Created by rannger on 2017/8/30.
//  Copyright © 2017年 yy. All rights reserved.
//

#import "json2pb.h"
#import <jansson.h>
#import <GPBUtilities.h>

static json_t * pb2jsonInternal(GPBMessage* msg,NSDictionary* map);
static json_t * field2json(GPBMessage* msg, GPBFieldDescriptor *field, size_t index,NSDictionary* map)
{
    BOOL repeated = ([field fieldType] == GPBFieldTypeRepeated);
    json_t* jf = NULL;

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

      __CASE(GPBDataTypeDouble, double, json_real, GPBDoubleArray,
             GPBGetMessageDoubleField);
      __CASE(GPBDataTypeFloat, double, json_real, GPBFloatArray,
             GPBGetMessageFloatField);
      __CASE(GPBDataTypeInt64, json_int_t, json_integer, GPBInt64Array,
             GPBGetMessageInt64Field);
      __CASE(GPBDataTypeSFixed64, json_int_t, json_integer, GPBInt64Array,
             GPBGetMessageInt64Field);
      __CASE(GPBDataTypeSInt64, json_int_t, json_integer, GPBInt64Array,
             GPBGetMessageInt64Field);
      __CASE(GPBDataTypeUInt64, json_int_t, json_integer, GPBUInt64Array,
             GPBGetMessageUInt64Field);
      __CASE(GPBDataTypeFixed64, json_int_t, json_integer, GPBUInt64Array,
             GPBGetMessageUInt64Field);
      __CASE(GPBDataTypeInt32, json_int_t, json_integer, GPBInt32Array,
             GPBGetMessageInt32Field);
      __CASE(GPBDataTypeSInt32, json_int_t, json_integer, GPBInt32Array,
             GPBGetMessageInt32Field);
      __CASE(GPBDataTypeSFixed32, json_int_t, json_integer, GPBInt32Array,
             GPBGetMessageInt32Field);
      __CASE(GPBDataTypeUInt32, json_int_t, json_integer, GPBUInt32Array,
             GPBGetMessageUInt32Field);
      __CASE(GPBDataTypeFixed32, json_int_t, json_integer, GPBUInt32Array,
             GPBGetMessageUInt32Field);
      __CASE(GPBDataTypeBool, bool, json_boolean, GPBBoolArray,
             GPBGetMessageBoolField);
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
            jf = json_string([value UTF8String]);
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
            char* buff = (char*)malloc(sizeof(uint8_t)*[data length]);
            [data getBytes:buff length:[data length]];
            jf = json_string(buff);
            free(buff);
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
            
            jf = pb2jsonInternal(mesg,map);
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

static json_t * pb2jsonInternal(GPBMessage* msg,NSDictionary* map)
{
    GPBDescriptor* d = [msg descriptor];
    json_t *root = json_object();
    
    for (GPBFieldDescriptor* field in [d fields]) {
        json_t *jf = 0;
        if ([field fieldType] == GPBFieldTypeRepeated) {
            NSArray* array = GPBGetMessageRepeatedField(msg, field);
            if ([array respondsToSelector:@selector(count)]&& [array count]!=0) {
                json_t* list = json_array();
                for (int i = 0; i<[array count]; ++i) {
                    json_array_append_new(list, field2json(msg, field, i, map));
                }
                jf = list;
            }
        } else if (GPBGetHasIvarField(msg, field)) {
            jf = field2json(msg, field, 0,map);
        } else {
            continue;
        }
        NSString* name = [field name];
        if (map!=nil && [[map objectForKey:name] isKindOfClass:[NSString class]] && [[map objectForKey:name] length]!=0) {
            name = [map objectForKey:name];
        }
        json_object_set_new(root, [name UTF8String], jf);
    }
    
    return root;
}

static void json2pbInternal(GPBMessage* msg, json_t *root,NSDictionary* keyMap);
static void json2fieldInternal(GPBMessage* msg, GPBFieldDescriptor* field, json_t *jf,NSDictionary* keyMap)
{
    BOOL repeated = ([field fieldType] == GPBFieldTypeRepeated);
    json_error_t error;
    
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
    ctype value;                                                               \
    int r = json_unpack_ex(jf, &error, JSON_STRICT, fmt, &value);              \
    if (r) {                                                                   \
      [NSException                                                             \
          exceptionWithName:@"json2field failed"                               \
                     reason:[NSString stringWithUTF8String:error.text]         \
                   userInfo:nil];                                              \
    }                                                                          \
    __SET_OR_ADD(sfunc, value, arraytype);                                     \
    break;                                                                     \
  }

      __CASE(GPBDataTypeDouble, double, "F", GPBDoubleArray,
             GPBSetMessageDoubleField);
      __CASE(GPBDataTypeFloat, double, "F", GPBFloatArray,
             GPBSetMessageFloatField);
      __CASE(GPBDataTypeInt64, json_int_t, "I", GPBInt64Array,
             GPBSetMessageInt64Field);

      __CASE(GPBDataTypeSFixed64, json_int_t, "I", GPBInt64Array,
             GPBSetMessageInt64Field);
      __CASE(GPBDataTypeSInt64, json_int_t, "I", GPBInt64Array,
             GPBSetMessageInt64Field);
      __CASE(GPBDataTypeUInt64, json_int_t, "I", GPBUInt64Array,
             GPBSetMessageUInt64Field);
      __CASE(GPBDataTypeFixed64, json_int_t, "I", GPBUInt64Array,
             GPBSetMessageUInt64Field);
      __CASE(GPBDataTypeInt32, json_int_t, "I", GPBInt32Array,
             GPBSetMessageInt32Field);
      __CASE(GPBDataTypeSInt32, json_int_t, "I", GPBInt32Array,
             GPBSetMessageInt32Field);
      __CASE(GPBDataTypeSFixed32, json_int_t, "I", GPBInt32Array,
             GPBSetMessageInt32Field);
      __CASE(GPBDataTypeUInt32, json_int_t, "I", GPBUInt32Array,
             GPBSetMessageUInt32Field);
      __CASE(GPBDataTypeFixed32, json_int_t, "I", GPBUInt32Array,
             GPBSetMessageUInt32Field);
      __CASE(GPBDataTypeBool, int, "b", GPBBoolArray, GPBSetMessageBoolField);
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
            if (!json_is_string(jf)) {
                [NSException exceptionWithName:@"Not a string" reason:@"Not a string" userInfo:nil];
            }
            const char * value = json_string_value(jf);
            NSString* string = [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
            __SET_OR_ADD(GPBSetMessageStringField, string, NSMutableArray);
        }
            break;
        case GPBDataTypeBytes:
        {
            if (!json_is_string(jf)) {
                [NSException exceptionWithName:@"Not a string" reason:@"Not a string" userInfo:nil];
            }
            const char * value = json_string_value(jf);
            NSString* string = [NSString stringWithUTF8String:value];
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
            json2pbInternal(mf, jf, keyMap);
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
            if (json_is_integer(jf)) {
               value = (uint32_t)json_integer_value(jf);
            } else if (json_is_string(jf)) {
                BOOL ret = [ed getValue:&value
                            forEnumName:[NSString stringWithUTF8String:json_string_value(jf)]];
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

static void json2pbInternal(GPBMessage* msg, json_t *root,NSDictionary* map)
{
    GPBDescriptor* d = [msg descriptor];
    if (!d)
        [NSException exceptionWithName:@"No descriptor or reflection"
                                reason:@"No descriptor or reflection"
                              userInfo:nil];
    
    for (void *i = json_object_iter(root); i; i = json_object_iter_next(root, i)) {
        const char *nameStr = json_object_iter_key(i);
        json_t *jf = json_object_iter_value(i);
        NSString* name = [NSString stringWithUTF8String:nameStr];
        if (map!=nil &&
            [[map objectForKey:name] isKindOfClass:[NSString class]] &&
            [[map objectForKey:name] length]!=0) {
            name = [map objectForKey:name];
        }
        GPBFieldDescriptor* field = [d fieldWithName:name];
        if (!field) {
            [NSException exceptionWithName:@"No descriptor or reflection"
                                    reason:@"No descriptor or reflection" userInfo:nil];
        }
        
        if ([field fieldType] == GPBFieldTypeRepeated) {
            if (!json_is_array(jf))
                [NSException exceptionWithName:@"Not array" reason:@"Not array" userInfo:nil];
            for (size_t j = 0; j<json_array_size(jf); ++j)
                json2fieldInternal(msg, field, json_array_get(jf, j), map);
        } else {
            json2fieldInternal(msg, field, jf, map);
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

+ (void)fromJson:(GPBMessage*)msg data:(NSData*)data keyMap:(NSDictionary*)map
{
    json_t *root = NULL;
    json_error_t error;
    
    root = json_loadb([data bytes], [data length], 0, &error);
    
    if (!root)
        [NSException exceptionWithName:@"Load failed"
                                reason:[NSString stringWithUTF8String:error.text]
                              userInfo:nil];
    
    if (!json_is_object(root))
        [NSException exceptionWithName:@"Malformed JSON: not an object"
                                reason:@"Malformed JSON: not an object"
                              userInfo:nil];
    
    json2pbInternal(msg, root, nil==map?@{}:map);
    
    json_decref(root);

}

+ (NSString*)toJson:(GPBMessage*)msg keyMap:(NSDictionary*)map
{
    NSMutableString* r = [NSMutableString stringWithCapacity:1024];
    json_t *root = pb2jsonInternal(msg,map==nil?@{}:map);
    json_dump_callback(root, jsonDumpString, (__bridge void*)r, 0);
    json_decref(root);
    return r;
}

- (id)initWithJson:(NSData*)data
{
    self = [self init];
    if (self) {
        [GPBMessage fromJson:self data:data keyMap:nil];
    }
    
    return self;
}

- (NSString*)toJson
{
    return [GPBMessage toJson:self keyMap:nil];
}

@end

