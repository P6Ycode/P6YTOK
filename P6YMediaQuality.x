#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <limits.h>
#import "P6YManager.h"
#import "P6YDownloadManager.h"
#import "P6YMediaQuality.h"

static id P6YAdvGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static NSNumber *P6YAdvNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) return @([(NSString *)value longLongValue]);
    if ([value isKindOfClass:NSDate.class]) return @([(NSDate *)value timeIntervalSince1970]);
    return nil;
}

static NSURL *P6YAdvURL(id item) {
    if ([item isKindOfClass:NSURL.class]) return item;
    if ([item isKindOfClass:NSString.class]) return [NSURL URLWithString:item];
    return nil;
}

#pragma mark - Highest-quality media selection

static NSInteger P6YURLQualityScore(id item) {
    NSURL *url = P6YAdvURL(item);
    if (!url) return NSIntegerMin;
    NSString *lower = url.absoluteString.lowercaseString;
    NSInteger score = 0;
    if ([lower containsString:@"original"] || [lower containsString:@"origin"]) score += 500000;
    if ([lower containsString:@"source"] || [lower containsString:@"raw"]) score += 350000;
    if ([lower containsString:@"2160"] || [lower containsString:@"4k"]) score += 216000;
    if ([lower containsString:@"1440"] || [lower containsString:@"2k"]) score += 144000;
    if ([lower containsString:@"1080"]) score += 108000;
    if ([lower containsString:@"720"]) score += 72000;
    if ([lower containsString:@"540"]) score += 54000;
    if ([lower containsString:@"480"]) score += 48000;
    if ([lower containsString:@"watermark"] || [lower containsString:@"wm=1"] || [lower containsString:@"logo"]) score -= 600000;
    if ([lower containsString:@"thumb"] || [lower containsString:@"resize"] || [lower containsString:@"crop"] || [lower containsString:@"preview"]) score -= 250000;
    if ([lower containsString:@"m3u8"]) score -= 100000;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *query in components.queryItems ?: @[]) {
        NSString *name = query.name.lowercaseString;
        NSInteger value = query.value.integerValue;
        if ([name containsString:@"width"] || [name isEqualToString:@"w"]) score += MIN(value, 5000) * 10;
        if ([name containsString:@"height"] || [name isEqualToString:@"h"]) score += MIN(value, 5000) * 10;
        if ([name containsString:@"bitrate"] || [name isEqualToString:@"br"]) score += MIN(value / 100, 100000);
    }
    return score;
}

NSArray *P6YSortURLItems(NSArray *items) {
    if (![items isKindOfClass:NSArray.class] || items.count < 2) return items;
    return [items sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
        NSInteger a = P6YURLQualityScore(left);
        NSInteger b = P6YURLQualityScore(right);
        if (a > b) return NSOrderedAscending;
        if (a < b) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

static id P6YBestURLModelFromBitrates(id video) {
    NSArray<NSString *> *arrayKeys = @[@"bitRate", @"bitRateModels", @"bitrateModels", @"bitRateInfo", @"videoBitrateInfo", @"bitrateInfo"];
    id bestModel = nil;
    long long bestScore = LLONG_MIN;
    for (NSString *arrayKey in arrayKeys) {
        id values = P6YAdvGet(video, arrayKey);
        if (![values isKindOfClass:NSArray.class]) continue;
        for (id value in (NSArray *)values) {
            long long bitrate = 0;
            for (NSString *key in @[@"bitRate", @"bitrate", @"bps", @"qualityType", @"quality"]) {
                bitrate = MAX(bitrate, [P6YAdvNumber(P6YAdvGet(value, key)) longLongValue]);
            }
            long long width = [P6YAdvNumber(P6YAdvGet(value, @"width")) longLongValue];
            long long height = [P6YAdvNumber(P6YAdvGet(value, @"height")) longLongValue];
            long long score = bitrate + width * height;
            id candidate = nil;
            for (NSString *key in @[@"playAddr", @"playURL", @"urlModel", @"gearURL", @"h264URL", @"downloadURL"]) {
                id possible = P6YAdvGet(value, key);
                if ([possible respondsToSelector:NSSelectorFromString(@"originURLList")] || [possible respondsToSelector:NSSelectorFromString(@"URLList")]) {
                    candidate = possible;
                    break;
                }
            }
            if (candidate && score > bestScore) {
                bestScore = score;
                bestModel = candidate;
            }
        }
    }
    return bestModel;
}

static id (*P6YOriginalVideoPlayURL)(id, SEL) = NULL;
static id P6YHighestQualityVideoPlayURL(id self, SEL _cmd) {
    id original = P6YOriginalVideoPlayURL ? P6YOriginalVideoPlayURL(self, _cmd) : nil;
    return P6YBestURLModelFromBitrates(self) ?: original;
}

static void P6YInstallHighestQualityGetter(void) {
    Class cls = objc_getClass("AWEVideoModel");
    Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(@"playURL")) : NULL;
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == (IMP)P6YHighestQualityVideoPlayURL) return;
    P6YOriginalVideoPlayURL = (id (*)(id, SEL))current;
    method_setImplementation(method, (IMP)P6YHighestQualityVideoPlayURL);
}

NSURL *P6YBestURLFromModel(id urlModel) {
    if (!urlModel) return nil;
    NSArray *items = P6YAdvGet(urlModel, @"originURLList");
    if (![items isKindOfClass:NSArray.class] || items.count == 0) items = P6YAdvGet(urlModel, @"URLList");
    items = P6YSortURLItems(items);
    for (id item in items) {
        NSURL *url = P6YAdvURL(item);
        if (url && ![url.absoluteString.lowercaseString containsString:@"m3u8"]) return url;
    }
    return P6YAdvURL(items.firstObject);
}

NSURL *P6YHQVideoURL(id model) {
    id video = P6YAdvGet(model, @"video");
    for (NSString *key in @[@"playURL", @"h264URL", @"h265URL", @"h264DownloadURL", @"downloadURL"]) {
        NSURL *url = P6YBestURLFromModel(P6YAdvGet(video, key));
        if (url) return url;
    }
    return nil;
}

NSArray<NSURL *> *P6YHQPhotoURLs(id model) {
    id album = P6YAdvGet(model, @"photoAlbum");
    NSArray *photos = P6YAdvGet(album, @"photos");
    if (![photos isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (id photo in photos) {
        NSURL *best = nil;
        for (NSString *key in @[@"originPhotoURL", @"downloadPhotoURL", @"imageURL", @"displayPhotoURL"]) {
            NSURL *url = P6YBestURLFromModel(P6YAdvGet(photo, key));
            if (url && (!best || P6YURLQualityScore(url) > P6YURLQualityScore(best))) best = url;
        }
        if (best) [urls addObject:best];
    }
    return urls;
}

%hook AWEURLModel
- (NSArray *)originURLList {
    return P6YSortURLItems(%orig);
}
%end

%hook AWESettingItemModel
- (void)setDetail:(NSString *)detail {
    if ([detail containsString:@"profile, and security"]) {
        detail = @"Full-quality downloads, LIVE, stories, profile, and Likes tools";
    }
    %orig(detail);
}
%end

#pragma mark - Full-resolution profile photo

static void (*P6YOriginalProfileLongPress)(id, SEL, UILongPressGestureRecognizer *) = NULL;
static void P6YFullResolutionProfileLongPress(id self, SEL _cmd, UILongPressGestureRecognizer *gesture) {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    id urlModel = nil;
    for (NSString *key in @[@"imageURL", @"avatarURL", @"urlModel", @"avatarUrlModel"]) {
        id value = P6YAdvGet(self, key);
        if (value) { urlModel = value; break; }
    }
    NSURL *url = P6YBestURLFromModel(urlModel);
    if (url) {
        [[P6YDownloadManager sharedManager] downloadURL:url kind:P6YMediaKindImage title:@"Profile photo saved"];
        return;
    }
    if (P6YOriginalProfileLongPress) P6YOriginalProfileLongPress(self, _cmd, gesture);
}

static void P6YInstallProfilePhotoHook(void) {
    Class cls = objc_getClass("AWEProfileImagePreviewView");
    Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(@"p6y_profileLongPress:")) : NULL;
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == (IMP)P6YFullResolutionProfileLongPress) return;
    P6YOriginalProfileLongPress = (void (*)(id, SEL, UILongPressGestureRecognizer *))current;
    method_setImplementation(method, (IMP)P6YFullResolutionProfileLongPress);
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        P6YInstallHighestQualityGetter();
        P6YInstallProfilePhotoHook();
    });
}
