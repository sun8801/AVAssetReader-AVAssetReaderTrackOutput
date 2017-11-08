//
//  ViewController.m
//  AVAssetReader+AVAssetReaderTrackOutput
//
//  Created by sunzongtang on 2017/11/8.
//  Copyright © 2017年 szt. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/objc.h>

extern CGImageRef imageFromSampleBufferRef(CMSampleBufferRef sampleBufferRef);

@interface ViewController ()

@property (nonatomic, strong) CALayer *playerLayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.playerLayer = [CALayer layer];
    self.playerLayer.frame = CGRectMake(0, 100, 375, 200);
    self.playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    self.playerLayer.contentsGravity = kCAGravityResizeAspect;
    [self.view.layer addSublayer:self.playerLayer];
    
    //path
    NSString *mp4Path = [[NSBundle mainBundle] pathForResource:@"Test2" ofType:@"mp4"];
    NSURL *mp4URL = [NSURL fileURLWithPath:mp4Path];
    
    //AVAsset
    AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:mp4URL options:nil];
    
    //AVAssetReader
    NSError *error;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:urlAsset error:&error];
    if (error) {
        NSLog(@"%@",error.localizedDescription);
        return;
    }
    
    //AVAssetTrack
    AVAssetTrack *videoTrack = [[urlAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    
    int m_pixelFormatType;
    //     视频播放时，
    m_pixelFormatType = kCVPixelFormatType_32BGRA;
    // 其他用途，如视频压缩
    // m_pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    NSDictionary *options = @{(id)kCVPixelBufferPixelFormatTypeKey:@(m_pixelFormatType)};
    
    //AVAssetReaderTrackOutput
    AVAssetReaderTrackOutput *videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:options];
    
    [assetReader addOutput:videoReaderOutput];
    [assetReader startReading];
    
    __block CMTime lastTime = kCMTimeZero;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while ([assetReader status] == AVAssetReaderStatusReading && videoTrack.nominalFrameRate > 0) {
            
            // 读取 video sample
            CMSampleBufferRef videoBuffer = [videoReaderOutput copyNextSampleBuffer];
            if (videoBuffer == NULL) {
                [assetReader cancelReading];
                break;
            }
            CGImageRef imageRef = imageFromSampleBufferRef(videoBuffer);

            dispatch_async(dispatch_get_main_queue(), ^{
                self.playerLayer.contents = (__bridge id)imageRef;
                CFRelease(imageRef);
            });
            
            CMTime bufferDuration = CMSampleBufferGetOutputPresentationTimeStamp(videoBuffer);
            CMTime pauseTime = CMTimeSubtract(bufferDuration,lastTime);
            lastTime = bufferDuration;
            
            CFRelease(videoBuffer);
            
            //根据需要休眠一段时间
            //根据PTS现实时间-暂停
             [NSThread sleepForTimeInterval:CMTimeGetSeconds(pauseTime)];
        }
    });
    
}


@end

// AVFoundation 捕捉视频帧，很多时候都需要把某一帧转换成 image
CGImageRef imageFromSampleBufferRef(CMSampleBufferRef sampleBufferRef)
{
    // 为媒体数据设置一个CMSampleBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef);
    // 锁定 pixel buffer 的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到 pixel buffer 的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到 pixel buffer 的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到 pixel buffer 的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的 RGB 颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphic context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //根据这个位图 context 中的像素创建一个 Quartz image 对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁 pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    // 释放 context 和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return quartzImage;
    
}

