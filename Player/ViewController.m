//
//  ViewController.m
//

#import "ViewController.h"
#import "PlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)showAVPlayer:(id)sender
{
    PlayerViewController *playerViewController  = [PlayerViewController sharedManager];
    [playerViewController playRemoteFile];
    [self.navigationController pushViewController:playerViewController animated:YES];
}

- (IBAction)showMediaPlayer:(id)sender
{
    
    MPMoviePlayerViewController *movieController = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL URLWithString:@"http://www-download.1tv.ru/promorolik/2013/11/VU-20131115-news.mp4"]];

    [self presentMoviePlayerViewControllerAnimated:movieController];
    [movieController.moviePlayer play];
}

@end
