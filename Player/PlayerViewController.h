//
//  PlayerViewController.h
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "PlayerVideoView.h"

@interface PlayerViewController : UIViewController
<AVAudioPlayerDelegate>
{
    BOOL seekToZeroBeforePlay;
    float mRestoreAfterScrubbingRate;
    id mTimeObserver;
    BOOL restoreVideoPlayStateAfterScrubbing;
    UISlider *scrubberSlider;
    UIButton *playPausebutton;
    NSURL *fileURL;
    PlayerVideoView *videoView;
}

@property (nonatomic, retain) AVPlayer *player;
@property (nonatomic, retain) AVPlayerItem *playerItem;

+ (instancetype)sharedManager;
- (void)viewDidLoad;
- (void)playRemoteFile;

@end
