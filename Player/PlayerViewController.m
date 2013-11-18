//
//  PlayerViewController.m
//

#import "PlayerViewController.h"

static NSString * const kTracksKey         = @"tracks";
static NSString * const kPlayableKey	   = @"playable";
static NSString * const kStatusKey         = @"status";
static NSString * const kRateKey		   = @"rate";
static NSString * const kCurrentItemKey	   = @"currentItem";

@implementation PlayerViewController

+ (instancetype)sharedManager
{
    static dispatch_once_t pred;
    static PlayerViewController *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[PlayerViewController alloc] init];
    });
    
    return shared;
}

- (void)viewDidLoad
{
    [self createInterface];
    
    [[AVAudioSession sharedInstance] setDelegate: self];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    [scrubberSlider addTarget:self action:@selector(beginScrubbing:) forControlEvents:UIControlEventTouchDown];
    [scrubberSlider addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpInside];
    [scrubberSlider addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpOutside];
    [scrubberSlider addTarget:self action:@selector(scrub:) forControlEvents:UIControlEventValueChanged];
    
    [playPausebutton addTarget:self action:@selector(playPause:) forControlEvents:UIControlEventTouchUpInside];
    
    [super viewDidLoad];
}

- (void)createInterface
{
    self.title = @"Player";
    self.view.backgroundColor = [UIColor whiteColor];
    scrubberSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 280, self.view.frame.size.width-40, 40.0)];
    playPausebutton = [UIButton buttonWithType:UIButtonTypeCustom];
    playPausebutton.frame = CGRectMake(50, 320, self.view.frame.size.width-100, 50.0);
    playPausebutton.backgroundColor = [UIColor redColor];
    [playPausebutton setTitle:@"LOADING" forState:UIControlStateNormal];
    
    videoView = [[PlayerVideoView alloc] initWithFrame:CGRectMake(20, 80, self.view.frame.size.width-40, 200)];
    
    //playPausebutton.enabled = NO;
    [self.view addSubview:scrubberSlider];
    [self.view addSubview:playPausebutton];
    [self.view addSubview:videoView];
}


///////////////////////////////////////////////
/// SCRUBBER
//////////////////////////////////////////////


- (void)initScrubberTimer
{
	double interval = .1f;
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		return;
	}
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([scrubberSlider bounds]);
		interval = 0.5f * duration / width;
	}
    
    __weak id weakSelf = self;
    CMTime intervalSeconds = CMTimeMakeWithSeconds(interval, NSEC_PER_SEC);
    mTimeObserver = [self.player addPeriodicTimeObserverForInterval:intervalSeconds
                                                              queue:dispatch_get_main_queue()
                                                         usingBlock:^(CMTime time) {
                                                             [weakSelf syncScrubber];
                                                         }];
    
}


- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		scrubberSlider.minimumValue = 0.0;
		return;
	}
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [scrubberSlider minimumValue];
		float maxValue = [scrubberSlider maximumValue];
		double time = CMTimeGetSeconds([self.player currentTime]);
		
		[scrubberSlider setValue:(maxValue - minValue) * time / duration + minValue];
	}
}

- (IBAction)beginScrubbing:(id)sender
{
    mRestoreAfterScrubbingRate = [self.player rate];
	[self.player setRate:0.f];
	
	[self removePlayerTimeObserver];
}


- (IBAction)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration))
        {
			return;
		}
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
		}
	}
}

- (IBAction)endScrubbing:(id)sender
{
    if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration))
		{
			return;
		}
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([scrubberSlider bounds]);
			double tolerance = 0.5f * duration / width;
            
            __weak id weakSelf = self;
            CMTime intervalSeconds = CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC);
            mTimeObserver = [self.player addPeriodicTimeObserverForInterval:intervalSeconds
                                                                      queue:dispatch_get_main_queue()
                                                                 usingBlock: ^(CMTime time) {
                                                                     [weakSelf syncScrubber];
                                                                 }];
		}
	}
    
    if (mRestoreAfterScrubbingRate)
	{
		[self.player setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
}

///////////////////////////////////////////////
/// ITEM
//////////////////////////////////////////////

- (BOOL)isPlaying
{
	return mRestoreAfterScrubbingRate != 0.f || [self.player rate] != 0.f;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
	seekToZeroBeforePlay = YES;
}

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [self.player currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}

- (void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[self.player removeTimeObserver:mTimeObserver];
		mTimeObserver = nil;
	}
}


///////////////////////////////////////////////
/// ASSET
//////////////////////////////////////////////

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
	}
    
    [self initScrubberTimer];
    
    if (self.playerItem)
    {
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
	
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [self.playerItem addObserver:self
                      forKeyPath:kStatusKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:nil];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
	
    seekToZeroBeforePlay = NO;
	
    if (!self.player)
    {
        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
        
        [self.player addObserver:self
                      forKeyPath:kCurrentItemKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:nil];
        
        [self.player addObserver:self
                      forKeyPath:kRateKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:nil];
    }
    
    if (self.player.currentItem != self.playerItem)
    {
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        [self syncPlayPauseButtons];
    }
}


- (void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


///////////////////////////////////////////////
/// OBSERVER
//////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    if ([path isEqualToString:@"status"])
	{
		[self syncPlayPauseButtons];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            case AVPlayerStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
            }
                break;
                
            case AVPlayerStatusReadyToPlay:
            {
                [self initScrubberTimer];
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
                break;
        }
	}
    
    else if ([path isEqualToString:@"rate"])
	{
        [self syncPlayPauseButtons];

	}
    
    else if ([path isEqualToString:@"currentItem"])
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        if (newPlayerItem == (id)[NSNull null])
        {

        }
        else
        {
            [videoView setPlayer:self.player];
            [videoView setVideoFillMode:AVLayerVideoGravityResizeAspect];
            [self syncPlayPauseButtons];
        }
	}
	else
	{
        NSLog(@"OTHER %@", path);
	}
}

///////////////////////////////////////////////
/// BUTTONS
//////////////////////////////////////////////

- (void)showPauseButton
{
    [playPausebutton setTitle:@"PAUSE" forState:UIControlStateNormal];
}

- (void)showPlayButton
{
     [playPausebutton setTitle:@"PLAY" forState:UIControlStateNormal];
}

- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showPauseButton];
	}
	else
	{
        [self showPlayButton];
	}
}

- (IBAction)playPause:(id)sender
{
	if ([self isPlaying])
    {
        [self.player pause];
    }
    else
    {
        if (YES == seekToZeroBeforePlay)
        {
            seekToZeroBeforePlay = NO;
            [self.player seekToTime:kCMTimeZero];
        }
        
        [self.player play];
    }
    [self syncPlayPauseButtons];
}


///////////////////////////////////////////////
/// Play remote file
//////////////////////////////////////////////

- (void)playRemoteFile
{
		NSURL *newMovieURL = [NSURL URLWithString:@"http://www-download.1tv.ru/promorolik/2013/11/VU-20131115-news.mp4"];
		if ([newMovieURL scheme])
		{
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:newMovieURL options:nil];
			NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];
			[asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
			 ^{
				 dispatch_async(dispatch_get_main_queue(),
                ^{
                        [self prepareToPlayAsset:asset withKeys:requestedKeys];
                 });
			 }];
		}
}

@end
