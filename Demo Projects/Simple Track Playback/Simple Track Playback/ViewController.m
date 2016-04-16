/*
 Copyright 2015 Spotify AB

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "Config.h"
#import "ViewController.h"
#import <Spotify/SPTDiskCache.h>

// RING0
#import "GCDAsyncSocket.h" // for TCP
#import "echo-config.h"

@interface ViewController () <SPTAudioStreamingDelegate, GCDAsyncSocketDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *albumLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UIImageView *coverView;
@property (weak, nonatomic) IBOutlet UIImageView *coverView2;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic, strong) SPTAudioStreamingController *player;

@end

@implementation ViewController {
    // RING0
    NSInteger pingIndex;
    NSInteger connectTries;
    GCDAsyncSocket *socket;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.titleLabel.text = @"Nothing Playing";
    self.albumLabel.text = @"";
    self.artistLabel.text = @"";
    pingIndex = 0;
    connectTries = 0;
    [self connectEchoChamber];
}

#pragma mark - RING0

- (void)connectEchoChamber
{
    [socket disconnect];
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue() socketQueue:dispatch_get_main_queue()];
    [socket connectToHost:ECHO_HOST onPort:ECHO_PORT error:nil];
    connectTries++;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"%s", __FUNCTION__);
    connectTries = 0;
    [sock performBlock:^{
        [sock enableBackgroundingOnSocket];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *response = [NSString stringWithFormat:@"%@\n%@\n", ECHO_KEY, ECHO_CHANNEL];
            [sock writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:5 tag:0];
            [sock readDataToData:[GCDAsyncSocket LFData] withTimeout:-1 tag:0];
        });
    }];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"%s", __FUNCTION__);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    [sock performBlock:^{
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([str isEqualToString:@"left"]) {
            [self.player skipPrevious:nil];
            NSLog(@"%d:%d", self.player.currentTrackIndex, self.player.trackListSize);
        } else if ([str isEqualToString:@"right"]) {
            [self.player skipNext:nil];
            NSLog(@"%d:%d", self.player.currentTrackIndex, self.player.trackListSize);
        } else if ([str isEqualToString:@"uptap"]) {
            [self.player setVolume:MIN(1.0, self.player.volume+0.1) callback:nil];
        } else if ([str isEqualToString:@"downtap"]) {
            [self.player setVolume:MAX(0.1, self.player.volume-0.1) callback:nil];
        } else if ([str isEqualToString:@"clockwise"]) {
            CGFloat len = self.player.currentTrackDuration / 4.0;
            [self.player seekToOffset:MIN(self.player.currentPlaybackPosition + len, self.player.currentTrackDuration) callback:nil];
        } else if ([str isEqualToString:@"counterclockwise"]) {
            CGFloat len = self.player.currentTrackDuration / 4.0;
            [self.player seekToOffset:MAX(self.player.currentPlaybackPosition - len, 0) callback:nil];
        } else if ([str isEqualToString:@"up"]) {
            // Up gesture
        } else if ([str isEqualToString:@"down"]) {
            [self.player setIsPlaying:!self.player.isPlaying callback:nil];
        } else {
            NSLog(@"Unknown: %@", str);
        }
        
        [sock readDataToData:[GCDAsyncSocket LFData] withTimeout:-1 tag:0];
    }];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    static BOOL doingIt = NO;
    if (self.player.isPlaying && !doingIt && connectTries < 10) {
        doingIt = YES;
        [self connectEchoChamber];
        dispatch_async(dispatch_get_main_queue(), ^{
            doingIt = NO;
        });
    }
    NSLog(@"%s", __FUNCTION__);
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
    NSLog(@"%s", __FUNCTION__);
}

#pragma mark -

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Actions

-(IBAction)rewind:(id)sender {
    [self.player skipPrevious:nil];
}

-(IBAction)playPause:(id)sender {
    [self.player setIsPlaying:!self.player.isPlaying callback:nil];
}

-(IBAction)fastForward:(id)sender {
    [self.player skipNext:nil];
}

- (IBAction)logoutClicked:(id)sender {
    SPTAuth *auth = [SPTAuth defaultInstance];
    if (self.player) {
        [self.player logout:^(NSError *error) {
            auth.session = nil;
            [self.navigationController popViewControllerAnimated:YES];
        }];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Logic


- (UIImage *)applyBlurOnImage: (UIImage *)imageToBlur
                   withRadius: (CGFloat)blurRadius {

    CIImage *originalImage = [CIImage imageWithCGImage: imageToBlur.CGImage];
    CIFilter *filter = [CIFilter filterWithName: @"CIGaussianBlur"
                                  keysAndValues: kCIInputImageKey, originalImage,
                        @"inputRadius", @(blurRadius), nil];

    CIImage *outputImage = filter.outputImage;
    CIContext *context = [CIContext contextWithOptions:nil];

    CGImageRef outImage = [context createCGImage: outputImage
                                        fromRect: [outputImage extent]];

    UIImage *ret = [UIImage imageWithCGImage: outImage];

    CGImageRelease(outImage);

    return ret;
}

-(void)updateUI {
    SPTAuth *auth = [SPTAuth defaultInstance];

    if (self.player.currentTrackURI == nil) {
        self.coverView.image = nil;
        self.coverView2.image = nil;
        return;
    }
    
    [self.spinner startAnimating];

    [SPTTrack trackWithURI:self.player.currentTrackURI
                   session:auth.session
                  callback:^(NSError *error, SPTTrack *track) {

                      self.titleLabel.text = track.name;
                      self.albumLabel.text = track.album.name;

                      SPTPartialArtist *artist = [track.artists objectAtIndex:0];
                      self.artistLabel.text = artist.name;

                      NSURL *imageURL = track.album.largestCover.imageURL;
                      if (imageURL == nil) {
                          NSLog(@"Album %@ doesn't have any images!", track.album);
                          self.coverView.image = nil;
                          self.coverView2.image = nil;
                          return;
                      }

                      // Pop over to a background queue to load the image over the network.
                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                          NSError *error = nil;
                          UIImage *image = nil;
                          NSData *imageData = [NSData dataWithContentsOfURL:imageURL options:0 error:&error];

                          if (imageData != nil) {
                              image = [UIImage imageWithData:imageData];
                          }


                          // …and back to the main queue to display the image.
                          dispatch_async(dispatch_get_main_queue(), ^{
                              [self.spinner stopAnimating];
                              self.coverView.image = image;
                              if (image == nil) {
                                  NSLog(@"Couldn't load cover image with error: %@", error);
                                  return;
                              }
                          });
                          
                          // Also generate a blurry version for the background
                          UIImage *blurred = [self applyBlurOnImage:image withRadius:10.0f];
                          dispatch_async(dispatch_get_main_queue(), ^{
                              self.coverView2.image = blurred;
                          });
                      });

    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self handleNewSession];
}

-(void)handleNewSession {
    SPTAuth *auth = [SPTAuth defaultInstance];

    if (self.player == nil) {
        self.player = [[SPTAudioStreamingController alloc] initWithClientId:auth.clientID];
        self.player.playbackDelegate = self;
        self.player.diskCache = [[SPTDiskCache alloc] initWithCapacity:1024 * 1024 * 64];
        self.player.shuffle = YES;
        [self.player setVolume:0.5 callback:nil];
    }

    [self.player loginWithSession:auth.session callback:^(NSError *error) {

		if (error != nil) {
			NSLog(@"*** Enabling playback got error: %@", error);
			return;
		}

        [self updateUI];
        
        NSURLRequest *playlistReq = [SPTPlaylistSnapshot createRequestForPlaylistWithURI:[NSURL URLWithString:@"spotify:user:epatel:playlist:2X5LMJg2KCgP5d6Ihc8Avm"]
                                                                             accessToken:auth.session.accessToken
                                                                                   error:nil];
        
        [[SPTRequest sharedHandler] performRequest:playlistReq callback:^(NSError *error, NSURLResponse *response, NSData *data) {
            if (error != nil) {
                NSLog(@"*** Failed to get playlist %@", error);
                return;
            }
            
            SPTPlaylistSnapshot *playlistSnapshot = [SPTPlaylistSnapshot playlistSnapshotFromData:data withResponse:response error:nil];
            
            [self.player playURIs:playlistSnapshot.firstTrackPage.items fromIndex:0 callback:nil];
        }];
	}];
}

#pragma mark - Track Player Delegates

- (void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didReceiveMessage:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didFailToPlayTrack:(NSURL *)trackUri {
    NSLog(@"failed to play track: %@", trackUri);
}

- (void) audioStreaming:(SPTAudioStreamingController *)audioStreaming didChangeToTrack:(NSDictionary *)trackMetadata {
    NSLog(@"track changed = %@", [trackMetadata valueForKey:SPTAudioStreamingMetadataTrackURI]);
    [self updateUI];
}

- (void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didChangePlaybackStatus:(BOOL)isPlaying {
    NSLog(@"is playing = %d", isPlaying);
}

@end
