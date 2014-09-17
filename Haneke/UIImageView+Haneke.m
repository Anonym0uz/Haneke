//
//  UIImageView+Haneke.m
//  Haneke
//
//  Created by Hermes Pique on 12/02/14.
//  Copyright (c) 2014 Hermes Pique. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "UIImageView+Haneke.h"
#import "HNKDiskFetcher.h"
#import "HNKSimpleFetcher.h"
#import "HNKNetworkFetcher.h"
#import "UIView+Haneke.h"
#import <objc/runtime.h>

@implementation UIImageView (Haneke)

- (void)hnk_setImageFromFile:(NSString*)path
{
    [self hnk_setImageFromFile:path placeholder:nil success:nil failure:nil];
}

- (void)hnk_setImageFromFile:(NSString*)path placeholder:(UIImage *)placeholder
{
    [self hnk_setImageFromFile:path placeholder:placeholder success:nil failure:nil];
}

- (void)hnk_setImageFromFile:(NSString*)path placeholder:(UIImage*)placeholder success:(void (^)(UIImage *image))successBlock failure:(void (^)(NSError *error))failureBlock
{
    id<HNKFetcher> entity = [[HNKDiskFetcher alloc] initWithPath:path];
    [self hnk_setImageFromEntity:entity placeholder:placeholder success:successBlock failure:failureBlock];
}

- (void)hnk_setImageFromURL:(NSURL*)url
{
    [self hnk_setImageFromURL:url placeholder:nil success:nil failure:nil];
}

- (void)hnk_setImageFromURL:(NSURL*)url placeholder:(UIImage *)placeholder
{
    [self hnk_setImageFromURL:url placeholder:placeholder success:nil failure:nil];
}

- (void)hnk_setImageFromURL:(NSURL*)url placeholder:(UIImage*)placeholder success:(void (^)(UIImage *image))successBlock failure:(void (^)(NSError *error))failureBlock
{
    id<HNKFetcher> entity = [[HNKNetworkFetcher alloc] initWithURL:url];
    [self hnk_setImageFromEntity:entity placeholder:placeholder success:successBlock failure:failureBlock];
}

- (void)hnk_setImage:(UIImage*)originalImage withKey:(NSString*)key
{
    [self hnk_setImage:originalImage withKey:key placeholder:nil success:nil failure:nil];
}

- (void)hnk_setImage:(UIImage*)originalImage withKey:(NSString*)key placeholder:(UIImage*)placeholder
{
    [self hnk_setImage:originalImage withKey:key placeholder:placeholder success:nil failure:nil];
}

- (void)hnk_setImage:(UIImage*)originalImage withKey:(NSString*)key placeholder:(UIImage*)placeholder success:(void (^)(UIImage *image))successBlock failure:(void (^)(NSError *error))failureBlock
{
    id<HNKFetcher> entity = [[HNKSimpleFetcher alloc] initWithKey:key image:originalImage];
    [self hnk_setImageFromEntity:entity placeholder:placeholder success:successBlock failure:failureBlock];
}

- (void)hnk_setImageFromEntity:(id<HNKFetcher>)entity
{
    [self hnk_setImageFromEntity:entity placeholder:nil success:nil failure:nil];
}

- (void)hnk_setImageFromEntity:(id<HNKFetcher>)entity placeholder:(UIImage*)placeholder
{
    [self hnk_setImageFromEntity:entity placeholder:placeholder success:nil failure:nil];
}

- (void)hnk_setImageFromEntity:(id<HNKFetcher>)entity placeholder:(UIImage*)placeholder success:(void (^)(UIImage *image))successBlock failure:(void (^)(NSError *error))failureBlock
{
    [self hnk_cancelSetImage];
    self.hnk_entity = entity;
    const BOOL didSetImage = [self hnk_fetchImageForEntity:entity success:successBlock failure:failureBlock];
    if (!didSetImage && placeholder != nil)
    {
        self.image = placeholder;
    }
}

- (void)setHnk_cacheFormat:(HNKCacheFormat *)cacheFormat
{
    [HNKCache registerSharedFormat:cacheFormat];
    objc_setAssociatedObject(self, @selector(hnk_cacheFormat), cacheFormat, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.contentMode = (UIViewContentMode)cacheFormat.scaleMode;
}

- (HNKCacheFormat*)hnk_cacheFormat
{
    HNKCacheFormat *format = (HNKCacheFormat *)objc_getAssociatedObject(self, @selector(hnk_cacheFormat));
    if (format) return format;

    CGSize viewSize = self.bounds.size;
    NSAssert(viewSize.width > 0 && viewSize.height > 0, @"%s: UImageView size is zero. Set its frame, call sizeToFit or force layout first.", __PRETTY_FUNCTION__);
    HNKScaleMode scaleMode = self.hnk_scaleMode;
    format = [HNKCache sharedFormatWithSize:viewSize scaleMode:scaleMode];
    return format;
}

- (void)hnk_cancelSetImage
{
    if ([self.hnk_entity respondsToSelector:@selector(cancelFetch)])
    {
        [self.hnk_entity cancelFetch];
    }
    self.hnk_entity = nil;
}

#pragma mark Private

- (BOOL)hnk_fetchImageForEntity:(id<HNKFetcher>)entity success:(void (^)(UIImage *image))successBlock failure:(void (^)(NSError *error))failureBlock
{
    HNKCacheFormat *format = self.hnk_cacheFormat;
    __block BOOL animated = NO;
    __weak __typeof__(self) weakSelf = self;
    const BOOL didSetImage = [[HNKCache sharedCache] fetchImageForEntity:entity formatName:format.name success:^(UIImage *image) {
        __typeof__(weakSelf) strongSelf = weakSelf;
        if ([strongSelf hnk_shouldCancelForKey:entity.cacheKey]) return;
        
        [strongSelf hnk_setImage:image animated:animated success:successBlock];
    } failure:^(NSError *error) {
        __typeof__(weakSelf) strongSelf = weakSelf;
        if ([strongSelf hnk_shouldCancelForKey:entity.cacheKey]) return;
        
        strongSelf.hnk_entity = nil;
        
        if (failureBlock) failureBlock(error);
    }];
    animated = YES;
    return didSetImage;
}

- (void)hnk_setImage:(UIImage*)image animated:(BOOL)animated success:(void (^)(UIImage *image))successBlock
{
    self.hnk_entity = nil;
    
    if (successBlock)
    {
        successBlock(image);
    }
    else
    {
        const NSTimeInterval duration = animated ? 0.1 : 0;
        [UIView transitionWithView:self duration:duration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self.image = image;
        } completion:nil];
    }
}

- (BOOL)hnk_shouldCancelForKey:(NSString*)key
{
    if ([self.hnk_entity.cacheKey isEqualToString:key]) return NO;
    
    HanekeLog(@"Cancelled set image for %@", key.lastPathComponent);
    return YES;
}

#pragma mark Properties (Private)

- (id<HNKFetcher>)hnk_entity
{
    return (id<HNKFetcher>)objc_getAssociatedObject(self, @selector(hnk_entity));
}

- (void)setHnk_entity:(id<HNKFetcher>)entity
{
    objc_setAssociatedObject(self, @selector(hnk_entity), entity, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
