//
//  PlayerVideoView.h
//
#import <AVFoundation/AVFoundation.h>

@interface PlayerVideoView : UIView

@property (nonatomic, retain) AVPlayer* player;
@property (nonatomic, retain) NSString* fillMode;

- (void)setPlayer:(AVPlayer*)player;
- (void)setVideoFillMode:(NSString *)fillMode;

@end
