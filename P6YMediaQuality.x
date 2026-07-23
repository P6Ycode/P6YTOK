#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <limits.h>
#import "P6YManager.h"
#import "P6YDownloadManager.h"
#import "P6YMediaQuality.h"

static id P6YQualityGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static long long P6YQualityInteger(id value) {
    if ([value isKindOfClass:NSNumber.class]) return [value longLongValue];
    if ([value isKindOfClass:NSString.class]) return [(NSString *)value longLongValue];
    return 0;
}

static NSURL *P6YQualityURL(id item) {
    if ([item isKindOfClass:NSURL.class]) return item;
    if ([item isKindOfClass:NSString.class]) return [NSURL URLWithString:item];
    return nil;
}

static NSString * const P6YQualityResolutionThreadKey = @"P6YTOK.ResolvingFullQualityDownload";

static BOOL P6YIsResolvingDownloadQuality(void) {
    return [NSThread.currentThread.threadDictionary[P6YQualityResolutionThreadKey] boolValue];
}

static void P6YPerformQualityResolution(dispatch_block_t block) {
    NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
    id previous = threadDictionary[P6YQualityResolutionThreadKey];
    threadDictionary[P6YQualityResolutionThreadKey] = @YES;
    @try {
        if (block) block();
    } @finally {
        if (previous) {
            threadDictionary[P6YQualityResolutionThreadKey] = previous;
        } else {
            [threadDictionary removeObjectForKey:P6YQualityResolutionThreadKey];
        }
    }
}

static long long P6YURLQualityScore(id item) {
    NSURL *url = P6YQualityURL(item);
    if (!url) return LLONG_MIN;

    NSString *lower = url.absoluteString.lowercaseString;
    long long score = 0;

    if ([lower containsString:@"original"] || [lower containsString:@"origin"]) score += 500000000LL;
    if ([lower containsString:@"source"] || [lower containsString:@"raw"]) score += 350000000LL;
    if ([lower containsString:@"2160"] || [lower containsString:@"4k"]) score += 216000000LL;
    if ([lower containsString:@"1440"] || [lower containsString:@"2k"]) score += 144000000LL;
    if ([lower containsString:@"1080"]) score += 108000000LL;
    if ([lower containsString:@"720"]) score += 72000000LL;
    if ([lower containsString:@"540"]) score += 54000000LL;
    if ([lower containsString:@"480"]) score += 48000000LL;

    if ([lower containsString:@"watermark"] || [lower containsString:@"wm=1"] || [lower containsString:@"logo"]) score -= 600000000LL;
    if ([lower containsString:@"thumb"] || [lower containsString:@"resize"] || [lower containsString:@"crop"] || [lower containsString:@"preview"]) score -= 250000000LL;
    if ([lower containsString:@".m3u8"]) score -= 100000000LL;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *query in components.queryItems ?: @[]) {
        NSString *name = query.name.lowercaseString;
        long long value = query.value.longLongValue;
        if ([name containsString:@"width"] || [name isEqualToString:@"w"]) score += MIN(value, 10000) * 10000;
        if ([name containsString:@"height"] || [name isEqualToString:@"h"]) score += MIN(value, 10000) * 10000;
        if ([name containsString:@"bitrate"] || [name isEqualToString:@"br"]) score += MIN(value, 100000000);
    }
    return score;
}

NSArray *P6YSortURLItems(NSArray *items) {
    if (![items isKindOfClass:NSArray.class] || items.count < 2) return items ?: @[];
    return [items sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
        long long a = P6YURLQualityScore(left);
        long long b = P6YURLQualityScore(right);
        if (a > b) return NSOrderedAscending;
        if (a < b) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

NSURL *P6YBestURLFromModel(id urlModel) {
    if (!urlModel) return nil;

    NSMutableArray *items = [NSMutableArray array];
    id origins = P6YQualityGet(urlModel, @"originURLList");
    id urls = P6YQualityGet(urlModel, @"URLList");
    if ([origins isKindOfClass:NSArray.class]) [items addObjectsFromArray:origins];
    if ([urls isKindOfClass:NSArray.class]) [items addObjectsFromArray:urls];

    NSArray *sorted = P6YSortURLItems(items);
    NSURL *streamFallback = nil;
    for (id item in sorted) {
        NSURL *url = P6YQualityURL(item);
        if (!url) continue;
        if ([url.absoluteString.lowercaseString containsString:@".m3u8"]) {
            if (!streamFallback) streamFallback = url;
            continue;
        }
        return url;
    }
    return streamFallback;
}

static long long P6YURLModelQualityScore(id urlModel) {
    if (!urlModel) return LLONG_MIN;

    long long width = 0;
    long long height = 0;
    long long bitrate = 0;
    long long size = 0;

    for (NSString *key in @[@"width", @"originWidth", @"videoWidth"]) {
        width = MAX(width, P6YQualityInteger(P6YQualityGet(urlModel, key)));
    }
    for (NSString *key in @[@"height", @"originHeight", @"videoHeight"]) {
        height = MAX(height, P6YQualityInteger(P6YQualityGet(urlModel, key)));
    }
    for (NSString *key in @[@"bitRate", @"bitrate", @"bps"]) {
        bitrate = MAX(bitrate, P6YQualityInteger(P6YQualityGet(urlModel, key)));
    }
    for (NSString *key in @[@"dataSize", @"fileSize", @"size"]) {
        size = MAX(size, P6YQualityInteger(P6YQualityGet(urlModel, key)));
    }

    long long score = width * height;
    score += MIN(bitrate, 1000000000LL);
    score += MIN(size / 16, 1000000000LL);

    NSURL *url = P6YBestURLFromModel(urlModel);
    if (url) score += P6YURLQualityScore(url);
    return score;
}

static id P6YBestBitrateURLModel(id video) {
    NSArray<NSString *> *arrayKeys = @[
        @"bitRate", @"bitRateModels", @"bitrateModels",
        @"bitRateInfo", @"videoBitrateInfo", @"bitrateInfo"
    ];

    id bestModel = nil;
    long long bestScore = LLONG_MIN;

    for (NSString *arrayKey in arrayKeys) {
        id values = P6YQualityGet(video, arrayKey);
        if (![values isKindOfClass:NSArray.class]) continue;

        for (id value in (NSArray *)values) {
            long long bitrate = 0;
            long long width = 0;
            long long height = 0;

            for (NSString *key in @[@"bitRate", @"bitrate", @"bps"]) {
                bitrate = MAX(bitrate, P6YQualityInteger(P6YQualityGet(value, key)));
            }
            for (NSString *key in @[@"width", @"videoWidth"]) {
                width = MAX(width, P6YQualityInteger(P6YQualityGet(value, key)));
            }
            for (NSString *key in @[@"height", @"videoHeight"]) {
                height = MAX(height, P6YQualityInteger(P6YQualityGet(value, key)));
            }

            id candidate = nil;
            for (NSString *key in @[@"playAddr", @"playURL", @"urlModel", @"gearURL", @"h265URL", @"h264URL", @"downloadURL"]) {
                id possible = P6YQualityGet(value, key);
                if (P6YBestURLFromModel(possible)) {
                    candidate = possible;
                    break;
                }
            }
            if (!candidate) continue;

            long long score = bitrate + width * height + P6YURLModelQualityScore(candidate);
            if (score > bestScore) {
                bestScore = score;
                bestModel = candidate;
            }
        }
    }
    return bestModel;
}

static id P6YBestVideoURLModel(id video, id playURLModel) {
    if (!video) return nil;

    NSMutableArray *candidates = [NSMutableArray array];
    id bitrateModel = P6YBestBitrateURLModel(video);
    if (bitrateModel) [candidates addObject:bitrateModel];

    if (playURLModel && P6YBestURLFromModel(playURLModel)) [candidates addObject:playURLModel];

    for (NSString *key in @[
        @"h265URL", @"h264URL",
        @"h264DownloadURL", @"downloadURL"
    ]) {
        id candidate = P6YQualityGet(video, key);
        if (P6YBestURLFromModel(candidate)) [candidates addObject:candidate];
    }

    id best = nil;
    long long bestScore = LLONG_MIN;
    for (id candidate in candidates) {
        long long score = P6YURLModelQualityScore(candidate);
        if (score > bestScore) {
            bestScore = score;
            best = candidate;
        }
    }
    return best;
}

NSURL *P6YHQVideoURL(id model) {
    id video = P6YQualityGet(model, @"video");
    id playURLModel = P6YQualityGet(video, @"playURL");
    return P6YBestURLFromModel(P6YBestVideoURLModel(video, playURLModel));
}

static id P6YBestPhotoURLModel(id photo, id originalModel) {
    NSMutableArray *candidates = [NSMutableArray array];
    if (originalModel) [candidates addObject:originalModel];

    for (NSString *key in @[@"downloadPhotoURL", @"imageURL", @"displayPhotoURL"]) {
        id candidate = P6YQualityGet(photo, key);
        if (P6YBestURLFromModel(candidate)) [candidates addObject:candidate];
    }

    id best = nil;
    long long bestScore = LLONG_MIN;
    for (id candidate in candidates) {
        long long score = P6YURLModelQualityScore(candidate);
        if (candidate == originalModel) score += 200000000LL;
        if (score > bestScore) {
            bestScore = score;
            best = candidate;
        }
    }
    return best ?: originalModel;
}

NSArray<NSURL *> *P6YHQPhotoURLs(id model) {
    id album = P6YQualityGet(model, @"photoAlbum");
    NSArray *photos = P6YQualityGet(album, @"photos");
    if (![photos isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSURL *> *urls = [NSMutableArray arrayWithCapacity:photos.count];
    for (id photo in photos) {
        id originalModel = P6YQualityGet(photo, @"originPhotoURL");
        id bestModel = P6YBestPhotoURLModel(photo, originalModel);
        NSURL *url = P6YBestURLFromModel(bestModel);
        if (url) [urls addObject:url];
    }
    return urls;
}

%hook AWEURLModel
- (NSArray *)originURLList {
    NSArray *original = %orig;
    return P6YIsResolvingDownloadQuality() ? P6YSortURLItems(original) : original;
}
%end

%hook AWEPhotoAlbumPhoto
- (id)originPhotoURL {
    id original = %orig;
    return P6YIsResolvingDownloadQuality() ? P6YBestPhotoURLModel(self, original) : original;
}
%end

static id (*P6YOriginalVideoPlayURL)(id, SEL) = NULL;

static id P6YHighestQualityVideoPlayURL(id self, SEL _cmd) {
    id original = P6YOriginalVideoPlayURL ? P6YOriginalVideoPlayURL(self, _cmd) : nil;
    if (!P6YIsResolvingDownloadQuality()) return original;

    id best = P6YBestVideoURLModel(self, original);
    if (!best) return original;

    long long originalScore = P6YURLModelQualityScore(original);
    long long bestScore = P6YURLModelQualityScore(best);
    return bestScore >= originalScore ? best : original;
}

static void P6YInstallHighestQualityVideoGetter(void) {
    Class cls = objc_getClass("AWEVideoModel");
    Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(@"playURL")) : NULL;
    if (!method) return;

    IMP current = method_getImplementation(method);
    if (current == (IMP)P6YHighestQualityVideoPlayURL) return;

    P6YOriginalVideoPlayURL = (id (*)(id, SEL))current;
    method_setImplementation(method, (IMP)P6YHighestQualityVideoPlayURL);
}

static void (*P6YOriginalFeedDownloadTap)(id, SEL) = NULL;
static void (*P6YOriginalDetailDownloadTap)(id, SEL) = NULL;
static void (*P6YOriginalStoryDownloadTap)(id, SEL) = NULL;

static void P6YFeedDownloadTap(id self, SEL _cmd) {
    P6YPerformQualityResolution(^{
        if (P6YOriginalFeedDownloadTap) P6YOriginalFeedDownloadTap(self, _cmd);
    });
}

static void P6YDetailDownloadTap(id self, SEL _cmd) {
    P6YPerformQualityResolution(^{
        if (P6YOriginalDetailDownloadTap) P6YOriginalDetailDownloadTap(self, _cmd);
    });
}

static void P6YStoryDownloadTap(id self, SEL _cmd) {
    P6YPerformQualityResolution(^{
        if (P6YOriginalStoryDownloadTap) P6YOriginalStoryDownloadTap(self, _cmd);
    });
}

static void P6YInstallDownloadTapHook(const char *className, IMP replacement, IMP *originalStorage) {
    Class cls = objc_getClass(className);
    Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(@"p6y_downloadTapped")) : NULL;
    if (!method) return;

    IMP current = method_getImplementation(method);
    if (current == replacement) return;

    *originalStorage = current;
    method_setImplementation(method, replacement);
}

static void P6YInstallDownloadResolutionHooks(void) {
    P6YInstallDownloadTapHook("AWEFeedViewTemplateCell", (IMP)P6YFeedDownloadTap, (IMP *)&P6YOriginalFeedDownloadTap);
    P6YInstallDownloadTapHook("AWEAwemeDetailTableViewCell", (IMP)P6YDetailDownloadTap, (IMP *)&P6YOriginalDetailDownloadTap);
    P6YInstallDownloadTapHook("TTKStoryDetailTableViewCell", (IMP)P6YStoryDownloadTap, (IMP *)&P6YOriginalStoryDownloadTap);
}

static void (*P6YOriginalProfileLongPress)(id, SEL, UILongPressGestureRecognizer *) = NULL;

static void P6YFullResolutionProfileLongPress(id self, SEL _cmd, UILongPressGestureRecognizer *gesture) {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    id bestModel = nil;
    long long bestScore = LLONG_MIN;
    for (NSString *key in @[@"imageURL", @"avatarURL", @"urlModel", @"avatarUrlModel"]) {
        id candidate = P6YQualityGet(self, key);
        long long score = P6YURLModelQualityScore(candidate);
        if (P6YBestURLFromModel(candidate) && score > bestScore) {
            bestScore = score;
            bestModel = candidate;
        }
    }

    NSURL *url = P6YBestURLFromModel(bestModel);
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

static void P6YScheduleQualityHookInstall(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        P6YInstallHighestQualityVideoGetter();
        P6YInstallDownloadResolutionHooks();
        P6YInstallProfilePhotoHook();
    });
}

%ctor {
    %init;
    P6YScheduleQualityHookInstall();
}
