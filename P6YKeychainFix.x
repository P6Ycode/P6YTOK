#import <Foundation/Foundation.h>
#import <Security/Security.h>

static CFDictionaryRef P6YKeychainDictionaryWithoutAccessGroup(CFDictionaryRef dictionary,
                                                                NSMutableDictionary **storage) {
    if (!dictionary) return dictionary;

    NSDictionary *source = (__bridge NSDictionary *)dictionary;
    id accessGroupKey = (__bridge id)kSecAttrAccessGroup;
    if (!source[accessGroupKey]) return dictionary;

    NSMutableDictionary *copy = [source mutableCopy];
    [copy removeObjectForKey:accessGroupKey];
    if (storage) *storage = copy;
    return (__bridge CFDictionaryRef)copy;
}

%hookf(OSStatus, SecItemAdd, CFDictionaryRef attributes, CFTypeRef *result) {
    NSMutableDictionary *storage = nil;
    CFDictionaryRef sanitized = P6YKeychainDictionaryWithoutAccessGroup(attributes, &storage);
    return %orig(sanitized, result);
}

%hookf(OSStatus, SecItemCopyMatching, CFDictionaryRef query, CFTypeRef *result) {
    NSMutableDictionary *storage = nil;
    CFDictionaryRef sanitized = P6YKeychainDictionaryWithoutAccessGroup(query, &storage);
    return %orig(sanitized, result);
}

%hookf(OSStatus, SecItemUpdate, CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    NSMutableDictionary *queryStorage = nil;
    NSMutableDictionary *updateStorage = nil;
    CFDictionaryRef sanitizedQuery = P6YKeychainDictionaryWithoutAccessGroup(query, &queryStorage);
    CFDictionaryRef sanitizedUpdate = P6YKeychainDictionaryWithoutAccessGroup(attributesToUpdate, &updateStorage);
    return %orig(sanitizedQuery, sanitizedUpdate);
}

%hookf(OSStatus, SecItemDelete, CFDictionaryRef query) {
    NSMutableDictionary *storage = nil;
    CFDictionaryRef sanitized = P6YKeychainDictionaryWithoutAccessGroup(query, &storage);
    return %orig(sanitized);
}
