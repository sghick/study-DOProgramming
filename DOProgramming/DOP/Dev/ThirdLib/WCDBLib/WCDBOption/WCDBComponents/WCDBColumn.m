//
//  WCDBColumn.m
//  WCDBLib
//
//  Created by 丁治文 on 2017/2/3.
//  Copyright © 2017年 WeiChe. All rights reserved.
//

#import "WCDBColumn.h"

NSString * const dbColumnTypeText = @"TEXT";
NSString * const dbColumnTypeBlob = @"BLOB";
NSString * const dbColumnTypeDate = @"DATE";
NSString * const dbColumnTypeReal = @"REAL";
NSString * const dbColumnTypeInteger = @"Integer";
NSString * const dbColumnTypeFloat = @"FLOAT";
NSString * const dbColumnTypeDouble = @"DOUBLE";
NSString * const dbColumnTypeBoolean = @"BOOLEAN";
NSString * const dbColumnTypeSmallint = @"Smallint";
NSString * const dbColumnTypeCurrency = @"Currency";
NSString * const dbColumnTypeVarchar = @"Varchar";
NSString * const dbColumnTypeBinary = @"Binary";
NSString * const dbColumnTypeTime = @"Time";
NSString * const dbColumnTypeTimestamp = @"Timestamp";

@implementation WCDBColumn

+ (instancetype)dbColumnWithAttributeString:(objc_property_t)property {
    if (!property) return nil;
    NSString *pName = nil;
    NSString *typeEncoding = nil;
    Class cls = NULL;
    NSString *ivarName = nil;
    const char *name = property_getName(property);
    if (name) {
        pName = [NSString stringWithUTF8String:name];
    }
    
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    if (typeEncoding.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:typeEncoding];
                        if (![scanner scanString:@"@\"" intoString:NULL]) continue;
                        
                        NSString *clsName = nil;
                        if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&clsName]) {
                            if (clsName.length) cls = objc_getClass(clsName.UTF8String);
                        }
                    }
                }
            } break;
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            default: break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    WCDBColumn *column = [[WCDBColumn alloc] initWithName:pName typeEncoding:typeEncoding ivarName:ivarName cls:cls];
    return column;
}

- (instancetype)initWithName:(NSString *)name typeEncoding:(NSString *)typeEncoding ivarName:(NSString *)ivarName cls:(__unsafe_unretained Class)cls {
    if (!name) return nil;
    self = [super init];
    if (self) {
        _name = name;
        _typeEncoding = typeEncoding;
        _ivarName = ivarName;
        _cls = cls;
        _property_type = [WCDBColumn judgePropertyTypeByTypeEncoding:typeEncoding cls:cls];
        _dbType = [WCDBColumn judgeDBTypeByTypeEncoding:typeEncoding];
    }
    return self;
}

- (NSString *)dbTypeSymbol {
    if (_dbTypeSymbol == nil) {
        return _dbType;
    }
    return _dbTypeSymbol;
}

- (BOOL)isEqualToDBColumn:(WCDBColumn *)column {
    if (![self.name isEqualToString:column.name]) {
        return NO;
    } else if (![self.dbType isEqualToString:column.dbType]) {
        return NO;
    }
    return YES;
}

- (NSString *)column_description {
    return [NSString stringWithFormat:@"{name:%@, dbType:%@, dbTypeSymbol:%@}", self.name, self.dbType, self.dbTypeSymbol];
}

- (NSString *)description {
    return [self column_description];
}

+ (NSDictionary *)dbTypeMapper {
    NSDictionary *rtn = @{
                          @"@\"NSString\"":dbColumnTypeText,
                          @"@\"NSMutableString\"":dbColumnTypeText,
                          @"@\"NSArray\"":dbColumnTypeBlob,
                          @"@\"NSMutableArray\"":dbColumnTypeBlob,
                          @"@\"NSDictionary\"":dbColumnTypeBlob,
                          @"@\"NSMutableDictionary\"":dbColumnTypeBlob,
                          @"@\"NSData\"":dbColumnTypeBlob,
                          @"@\"NSDate\"":dbColumnTypeBlob,
                          @"@\"NSNumber\"":dbColumnTypeReal,
                          @"@\"NSValue\"":dbColumnTypeReal,
                          @"q":dbColumnTypeInteger,
                          @"i":dbColumnTypeInteger,
                          @"f":dbColumnTypeFloat,
                          @"d":dbColumnTypeDouble,
                          @"B":dbColumnTypeBoolean,
                          @"b":dbColumnTypeBoolean,
                          @"C":dbColumnTypeVarchar,
                          @"c":dbColumnTypeVarchar,
                          @"?":dbColumnTypeBlob
                          };
    return rtn;
}

// private
+ (NSArray *)valuePropertyTypes {
    NSArray *rtn = @[@"q",
                     @"i",
                     @"f",
                     @"d",
                     @"B",
                     @"b",
                     @"C",
                     @"c"];
    return rtn;
}

// private
+ (NSArray *)arrayPropertyTypes {
    NSArray *rtn = @[@"@\"NSArray\"",
                     @"@\"NSMutableArray\""];
    return rtn;
}

// private
+ (NSArray *)dictionaryPropertyTypes {
    NSArray *rtn = @[@"@\"NSDictionary\"",
                     @"@\"NSMutableDictionary\""];
    return rtn;
}

+ (WCDBPropertyType)judgePropertyTypeByTypeEncoding:(NSString *)typeEncoding cls:(Class)cls {
    if (!typeEncoding) {
        return WCDBPropertyTypeUnknow;
    }
    if ([typeEncoding isEqualToString:@"?"]) {
        return WCDBPropertyTypeUnknow;
    }
    
    if (cls != NULL) {
        if ([[self arrayPropertyTypes] containsObject:typeEncoding]) {
            return WCDBPropertyTypeArray;
        }
        if ([[self dictionaryPropertyTypes] containsObject:typeEncoding]) {
            return WCDBPropertyTypeDictionary;
        }
        if (![[self dbTypeMapper].allKeys containsObject:typeEncoding]) {
            return WCDBPropertyTypeCustom;
        }
        if ([typeEncoding isEqualToString:@"@\"NSDate\""]) {
            return WCDBPropertyTypeDate;
        }
    } else {
        if ([[self valuePropertyTypes] containsObject:typeEncoding]) {
            return WCDBPropertyTypeValue;
        }
    }
    return WCDBPropertyTypeUnknow;
}

+ (NSString *)judgeDBTypeByTypeEncoding:(NSString *)typeEncoding {
    NSString *dbType = nil;
    if (typeEncoding) {
        dbType = [WCDBColumn dbTypeMapper][typeEncoding];
    }
    if (dbType == nil) {
        dbType = dbColumnTypeBlob;
    }
    return dbType;
}

@end
