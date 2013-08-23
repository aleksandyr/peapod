//
//  KBiPodRemote.m
//  pebbleremote
//
//  Created by Katharine Berry on 25/05/2013.
//  Copyright (c) 2013 Katharine Berry. All rights reserved.
//

#import "KBiPodRemote.h"
#import <PebbleKit/PebbleKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "KBPebbleMessageQueue.h"
#import "KBPebbleImage.h"

#define IPOD_UUID { 0x24, 0xCA, 0x78, 0x2C, 0xB3, 0x1F, 0x49, 0x04, 0x83, 0xE9, 0xCA, 0x51, 0x9C, 0x60, 0x10, 0x97 }

#define IPOD_RECONNECT_KEY @(0xFEFF)
#define IPOD_REQUEST_LIBRARY_KEY @(0xFEFE)
#define IPOD_REQUEST_OFFSET_KEY @(0xFEFB)
#define IPOD_LIBRARY_RESPONSE_KEY @(0xFEFD)
#define IPOD_NOW_PLAYING_KEY @(0xFEFA)
#define IPOD_REQUEST_PARENT_KEY @(0xFEF9)
#define IPOD_PLAY_TRACK_KEY @(0xFEF8)
#define IPOD_NOW_PLAYING_RESPONSE_TYPE_KEY @(0xFEF7)
#define IPOD_ALBUM_ART_KEY @(0xFEF6)
#define IPOD_CHANGE_STATE_KEY @(0xFEF5)
#define IPOD_CURRENT_STATE_KEY @(0xFEF4)
#define IPOD_SEQUENCE_NUMBER_KEY @(0xFEF3)

#define FIND_PHONE_PLAY_SOUND_KEY @(0xFEE1)
#define GET_BATTERY_STATUS_KEY @(0xFEE2)
#define GET_NOTES_LIST_KEY @(0xFEE3)
#define GET_SPECIFIC_NOTE_KEY @(0xFEE4)


#define MAX_LABEL_LENGTH 20
#define MAX_RESPONSE_COUNT 15
#define MAX_OUTGOING_SIZE 105 // This allows some overhead.

#define systemSoundIDNTink   1103
#define systemSoundIDTonk    1104
#define systemSoundIDNNewsFlash    1028
#define systemSoundIDNoir    1029
#define systemSoundIDUpdate    1036


typedef enum {
    NowPlayingTitle,
    NowPlayingArtist,
    NowPlayingAlbum,
    NowPlayingTitleArtist,
    NowPlayingNumbers,
} NowPlayingType;

@interface KBiPodRemote () {
    PBWatch *our_watch;
    MPMusicPlayerController *music_player;
    KBPebbleMessageQueue *message_queue;
    uint32_t last_sequence_number;
}

- (void)setWatch:(PBWatch*)watch;
- (void)watch:(PBWatch*)watch receivedMessage:(NSDictionary*)message;
- (void)watch:(PBWatch*)watch wantsLibraryData:(NSDictionary*)request;
- (void)pushLibraryResults:(NSArray*)results withOffset:(NSInteger)offset toWatch:(PBWatch*)watch type:(MPMediaGrouping)type;
- (void)musicItemChanged:(MPMediaItem*)item;
- (void)pushNowPlayingItemToWatch:(PBWatch*)watch detailed:(BOOL)detailed;
- (void)sendStringArray:(NSArray *)stringArray withKey:(id)key;
- (void)PushBatteryStatusToWatch;

@end

@implementation KBiPodRemote

- (id)init
{
    self = [super init];
    if (self) {
        message_queue = [[KBPebbleMessageQueue alloc] init];
        [[PBPebbleCentral defaultCentral] setDelegate:self];
        [self setWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
        music_player = [MPMusicPlayerController iPodMusicPlayer];
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(musicItemChanged:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:music_player];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(musicStateChanged:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:music_player];
        [music_player beginGeneratingPlaybackNotifications];
        
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        [arr addObject:[NSString stringWithFormat:@"Test Note 0>#^#Urban Terrorists Bangladesh, aka UrTBD, is the first intern! Here is the max text \n limit we are testing now!<> First off thanks for the app and httpebble, your works greatly appreciated. I'm having difficulty installing the .ipa on my phone. I can download it via itunes, but it refuses to install."]];
        
        for (int i=1;i<5;i++)
        {
            //[arr addObject:[NSString stringWithFormat:@"Test Note num %d#^#Urban  %d  Terrorists Bangladesh, aka UrTBD, is the first intern! Here is the max text \n limit we are testing now!<>", i,i]];
            [arr addObject:[NSString stringWithFormat:@"Test Note %d 123456789012345678#^#Urban  %d  Terrorists Bangladesh, aka UrTBD, is the first intern! Here is the max text \n limit we are testing now!<> First off thanks for the app and httpebble, your works greatly appreciated. I'm having difficulty installing the .ipa on my phone. I can download it via itunes, but it refuses to install. It'll appear on my iphone 4s but it won't actually install. Oh, and I've managed to download via other methods it just refuses to install. Any suggestions? Thanks. Urban Terrorists Bangladesh, aka UrTBD, is the first intern! Here is the max text \n limit we are testing now!<>First off thanks for the app and httpebble, your works greatly appreciated. I'm having difficulty.1234567890123456789 First off thanks for the app and httpebble, your works greatly appreciated. I'm having difficulty.1234567890123456789First off thanks for the app and httpebble, your works greatly appreciated. I'm having difficulty.1234567890123456789First off thanks for the app and httpebble, your works greatly>>", i,i]];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"Notes"];
    }
    return self;
}

- (void)musicItemChanged:(MPMediaItem *)item {
    [self pushNowPlayingItemToWatch:our_watch detailed:YES];
}

- (void)musicStateChanged:(MPMusicPlaybackState)state {
    [self pushCurrentStateToWatch:our_watch];
}

- (void)pushCurrentStateToWatch:(PBWatch *)watch {
    uint16_t current_time = (uint16_t)[music_player currentPlaybackTime];
    uint16_t total_time = (uint16_t)[[[music_player nowPlayingItem] valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    uint8_t metadata[] = {
        [music_player playbackState],
        [music_player shuffleMode],
        [music_player repeatMode],
        total_time >> 8, total_time & 0xFF,
        current_time >> 8, current_time & 0xFF
    };
    NSLog(@"Current state: %@", [NSData dataWithBytes:metadata length:7]);
    [message_queue enqueue:@{IPOD_CURRENT_STATE_KEY: [NSData dataWithBytes:metadata length:7]}];

}

- (void)pushNowPlayingItemToWatch:(PBWatch *)watch detailed:(BOOL)detailed {
    MPMediaItem *item = [music_player nowPlayingItem];
    NSString *title = [item valueForProperty:MPMediaItemPropertyTitle];
    NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
    NSString *album = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
    if(!title) title = @"";
    if(!artist) artist = @"";
    if(!album) album = @"";
    if(!detailed) {
        NSString *value;
        if(!item) {
            value = @"Nothing playing.";
        } else {
            value = [NSString stringWithFormat:@"%@ - %@", title, artist, nil];
        }
        if([value length] > MAX_OUTGOING_SIZE) {
            value = [value substringToIndex:MAX_OUTGOING_SIZE];
        }
        [message_queue enqueue:@{IPOD_NOW_PLAYING_KEY: value, IPOD_NOW_PLAYING_RESPONSE_TYPE_KEY: @(NowPlayingTitleArtist)}];
        NSLog(@"Now playing: %@", value);
    } else {
        NSLog(@"Pushing everything.");
        [self pushCurrentStateToWatch:watch];
        [message_queue enqueue:@{IPOD_NOW_PLAYING_KEY: title, IPOD_NOW_PLAYING_RESPONSE_TYPE_KEY: @(NowPlayingTitle)}];
        [message_queue enqueue:@{IPOD_NOW_PLAYING_KEY: artist, IPOD_NOW_PLAYING_RESPONSE_TYPE_KEY:@(NowPlayingArtist)}];
        [message_queue enqueue:@{IPOD_NOW_PLAYING_KEY: album, IPOD_NOW_PLAYING_RESPONSE_TYPE_KEY: @(NowPlayingAlbum)}];
        
        // Get and send the artwork.
        MPMediaItemArtwork *artwork = [item valueForProperty:MPMediaItemPropertyArtwork];
        if(artwork) {
            UIImage* image = [artwork imageWithSize:CGSizeMake(64, 64)];
            if(!image) {
                [message_queue enqueue:@{IPOD_ALBUM_ART_KEY: [NSNumber numberWithUint8:255]}];
            }
            else {
                NSData *bitmap = [KBPebbleImage ditheredBitmapFromImage:image withHeight:64 width:64];
                size_t length = [bitmap length];
                uint8_t j = 0;
                for(size_t i = 0; i < length; i += MAX_OUTGOING_SIZE-1) {
                    NSMutableData *outgoing = [[NSMutableData alloc] initWithCapacity:MAX_OUTGOING_SIZE];
                    [outgoing appendBytes:&j length:1];
                    [outgoing appendData:[bitmap subdataWithRange:NSMakeRange(i, MIN(MAX_OUTGOING_SIZE-1, length - i))]];
                    [message_queue enqueue:@{IPOD_ALBUM_ART_KEY: outgoing}];
                    ++j;
                }
            }
        }
    }
}

- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew {
    [self setWatch:watch];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch
{
    AudioServicesPlaySystemSound (systemSoundIDNoir);
    NSLog(@"Watch disconnected %@",[watch name]);
}

- (void)setWatch:(PBWatch *)watch {
    NSLog(@"Have a watch.");
    if(![watch isConnected]) {
        NSLog(@"Not connected.");
        return;
    }
    [watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        NSLog(@"Useful watch %@ connected.", [watch name]);
        last_sequence_number = 0;
        our_watch = watch;
        message_queue.watch = watch;
        // Send a message to make sure it's awake and that we have a session.
        uint8_t uuid[] = IPOD_UUID;
        [watch appMessagesSetUUID:[NSData dataWithBytes:uuid length:16]];
        [watch appMessagesPushUpdate:@{IPOD_RECONNECT_KEY: @(1)} onSent:nil];
        [watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
            [self watch:watch receivedMessage:update];
            return YES;
        }];
    }];
    AudioServicesPlaySystemSound (systemSoundIDNNewsFlash);
}

- (void)watch:(PBWatch *)watch receivedMessage:(NSDictionary *)message {
    NSLog(@"Received message: %@", message);
    uint32_t sequence_number = [message[IPOD_SEQUENCE_NUMBER_KEY] uint32Value];
    if(sequence_number == 0xFFFFFFFF) {
        NSLog(@"Reset sequence numbers.");
        last_sequence_number = 0;
    } else {
        if(sequence_number <= last_sequence_number) {
            NSLog(@"Discarding duplicate message.");
            return;
        }
        last_sequence_number = sequence_number;
    }
    if(message[IPOD_PLAY_TRACK_KEY])
    {
        [self watch:watch playTrackFromMessage:message];
    }
    else if(message[IPOD_REQUEST_LIBRARY_KEY])
    {
        if(message[IPOD_REQUEST_PARENT_KEY])
        {
            [self watch:watch wantsSubList:message];
        }
        else
        {
            [self watch:watch wantsLibraryData:message];
        }
    }
    else if(message[IPOD_NOW_PLAYING_KEY])
    {
        [self pushNowPlayingItemToWatch:watch detailed:[message[IPOD_NOW_PLAYING_KEY] boolValue]];
    }
    else if(message[IPOD_CHANGE_STATE_KEY])
    {
        [self changeState:[message[IPOD_CHANGE_STATE_KEY] integerValue]];
    }
    else if(message[FIND_PHONE_PLAY_SOUND_KEY])
    {
        
       NSInteger state = [message[FIND_PHONE_PLAY_SOUND_KEY] integerValue];
        switch(state) {
            case 0:
            {
                AudioServicesPlaySystemSound (systemSoundIDUpdate);
                [message_queue enqueue:@{FIND_PHONE_PLAY_SOUND_KEY: [NSNumber numberWithUint8:255]}];
                break;
            }
            case 64:
            {
                 MPMusicPlayerController *app_music_player = [MPMusicPlayerController applicationMusicPlayer];
                [app_music_player setVolume:[app_music_player volume] + 0.0625];
                break;
            }
            case -64:
            {
                MPMusicPlayerController *app_music_player = [MPMusicPlayerController applicationMusicPlayer];
                [app_music_player setVolume:[app_music_player volume] - 0.0625];
                break;
            }
        }
        
        //[self performSelector:@selector(wakemeUp) withObject:nil afterDelay:7];
    }
    else if(message[GET_NOTES_LIST_KEY])
    {
        NSArray *notesArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Notes"];
        NSMutableArray *titleArray = [[NSMutableArray alloc] init];
        for (NSString *note in notesArray)
        {
            NSString *substring = nil;
            NSRange breakString = [note rangeOfString:@"#^#"];
            if(breakString.location != NSNotFound) {
                substring = [note substringToIndex:breakString.location];
            }
            [titleArray addObject:(([substring length] > 15) ? [substring substringToIndex:15] : substring)];//allowing max 15 characters note Title to prevent buffer overflow
        }
        [self sendStringArray:titleArray withKey:GET_NOTES_LIST_KEY];
    }
    else if(message[GET_SPECIFIC_NOTE_KEY])
    {
        NSArray *notesArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Notes"];

            NSString *substring = [notesArray objectAtIndex:[message[GET_SPECIFIC_NOTE_KEY] integerValue]];
            NSRange breakString = [substring rangeOfString:@"#^#"];
            if(breakString.location != NSNotFound) {
                substring = [substring substringFromIndex:breakString.location];
                 substring = [substring stringByReplacingOccurrencesOfString:@"#^#" withString:@""];
            }
        substring = (([substring length] > 999) ? [substring substringToIndex:999] : substring);//allowing max 999 characters note size 
        NSData *note = [substring dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        size_t length = [note length];
        uint8_t j = 0;
        for(size_t i = 0; i < length; i += MAX_OUTGOING_SIZE-1) {
            NSMutableData *outgoing = [[NSMutableData alloc] initWithCapacity:MAX_OUTGOING_SIZE];
            [outgoing appendBytes:&j length:1];
            [outgoing appendData:[note subdataWithRange:NSMakeRange(i, MIN(MAX_OUTGOING_SIZE-1, length - i))]];
            [message_queue enqueue:@{GET_SPECIFIC_NOTE_KEY: outgoing}];
            ++j;
        }
        NSLog(@"Wrote note %d:%@",[message[GET_SPECIFIC_NOTE_KEY] integerValue], substring);
    }
    else if(message[GET_BATTERY_STATUS_KEY])
    {
        [self PushBatteryStatusToWatch];
    }
}
- (void)sendStringArray:(NSArray *)stringArray withKey:(id)key
{
    if (!our_watch)
    {
        NSLog(@"No watch to send the Notes List");
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    [stringArray enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
        dictionary[[NSNumber numberWithInt8:(int8_t)idx]] = string;
    }];
    
    [our_watch appMessagesPushUpdate:dictionary onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
        NSLog(@"Dictionary %@ sent with No error:%@", dictionary, error);
        
        if (error)
        {
            NSLog(@"%@",[error description]);
        }
    }];
}

-(void)PushBatteryStatusToWatch
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    int levelInt = roundf([[UIDevice currentDevice] batteryLevel]*100);
    int8_t batteryLevel = (int8_t)levelInt;
    int8_t state = (int8_t)[[UIDevice currentDevice] batteryState];
    uint8_t metadata[] = {
        batteryLevel,
        state
    };
    NSLog(@"Current battery status: %@ , percent:%zd, State:%zd", [NSData dataWithBytes:metadata length:2], batteryLevel, state);
    [message_queue enqueue:@{GET_BATTERY_STATUS_KEY: [NSData dataWithBytes:metadata length:2]}];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
}

/*-(void)wakemeUp
{
    [our_watch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Error sending wakeUp Call: %@", error);
        }
    }];
    [self performSelector:@selector(wakemeUp1) withObject:nil afterDelay:7];
}
-(void)wakemeUp1
{
    [message_queue enqueue:@{FIND_PHONE_PLAY_SOUND_KEY: [NSNumber numberWithUint8:255]}];
    NSLog(@"sending vibe");
}
*/
- (void)changeState:(NSInteger)state {
    switch(state) {
        case 0:
            if([music_player playbackState] == MPMusicPlaybackStatePlaying) [music_player pause];
            else [music_player play];
            //[self performSelector:@selector(pushCurrentStateToWatch:) withObject:our_watch afterDelay:0.1];
            break;
        case 1:
            [music_player skipToNextItem];
            [self pushNowPlayingItemToWatch:our_watch detailed:YES];
            break;
        case -1:
            if([music_player currentPlaybackTime] < 3) {
                [music_player skipToPreviousItem];
                [self pushNowPlayingItemToWatch:our_watch detailed:YES];
            } else {
                [music_player skipToBeginning];
                [self performSelector:@selector(pushCurrentStateToWatch:) withObject:our_watch afterDelay:0.1];
            }
            break;
        case 64:
            [music_player setVolume:[music_player volume] + 0.0625];
            break;
        case -64:
            [music_player setVolume:[music_player volume] - 0.0625];
            break;
    }
}

- (void)watch:(PBWatch*)watch playTrackFromMessage:(NSDictionary *)message {
    MPMediaItemCollection *queue = [self getCollectionFromMessage:message][0];
    MPMediaItem *track = [queue items][[message[IPOD_PLAY_TRACK_KEY] int16Value]];
    [music_player setQueueWithItemCollection:queue];
    [music_player setNowPlayingItem:track];
    [music_player play];
    [self pushNowPlayingItemToWatch:watch detailed:YES];
}

- (void)watch:(PBWatch *)watch wantsLibraryData:(NSDictionary *)request {
    NSUInteger request_type = [request[IPOD_REQUEST_LIBRARY_KEY] unsignedIntegerValue];
    NSUInteger offset = [request[IPOD_REQUEST_OFFSET_KEY] integerValue];
    MPMediaQuery *query = [[MPMediaQuery alloc] init];
    [query setGroupingType:request_type];
    [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:@(MPMediaTypeMusic) forProperty:MPMediaItemPropertyMediaType]];
    NSArray* results = [query collections];
    [self pushLibraryResults:results withOffset:offset toWatch:watch type:request_type];
}

- (NSArray*)getCollectionFromMessage:(NSDictionary*)request {
    // Find what we're subsetting by iteratively grabbing the sets.
    MPMediaItemCollection *collection = nil;
    MPMediaGrouping parent_type;
    uint16_t parent_index;
    NSString *persistent_id;
    NSString *id_prop;
    NSData *data = request[IPOD_REQUEST_PARENT_KEY];
    uint8_t *bytes = (uint8_t*)[data bytes];
    for(uint8_t i = 0; i < bytes[0]; ++i) {
        parent_type = bytes[i*3+1];
        parent_index = *(uint16_t*)&bytes[i*3+2];
        NSLog(@"Parent type: %d", parent_type);
        NSLog(@"Parent index: %d", parent_index);
        NSLog(@"i: %d", i);
        MPMediaQuery *query = [[MPMediaQuery alloc] init];
        [query setGroupingType:parent_type];
        [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:@(MPMediaTypeMusic) forProperty:MPMediaItemPropertyMediaType]];
        if(collection) {
            [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:persistent_id forProperty:id_prop]];
        }
        if(parent_index >= [[query collections] count]) {
            NSLog(@"Out of bounds: %d", parent_index);
            return nil;
        }
        collection = [query collections][parent_index];
        id_prop = [MPMediaItem persistentIDPropertyForGroupingType:parent_type];
        persistent_id = [[collection representativeItem] valueForProperty:id_prop];
    }
    
    // Complete the lookup
    NSUInteger request_type = [request[IPOD_REQUEST_LIBRARY_KEY] unsignedIntegerValue];
    if(request_type == MPMediaGroupingTitle) {
        return @[collection];
    } else {
        NSLog(@"Got persistent ID: %@", persistent_id);
        MPMediaQuery *query = [[MPMediaQuery alloc] init];
        [query setGroupingType:request_type];
        [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:persistent_id forProperty:id_prop]];
        [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:@(MPMediaTypeMusic) forProperty:MPMediaItemPropertyMediaType]];
        return [query collections];
    }
}

- (void)watch:(PBWatch*)watch wantsSubList:(NSDictionary*)request {
    NSArray *results = [self getCollectionFromMessage:request];
    MPMediaGrouping request_type = [request[IPOD_REQUEST_LIBRARY_KEY] integerValue];
    uint16_t offset = [request[IPOD_REQUEST_OFFSET_KEY] uint16Value];
    if(request_type == MPMediaGroupingTitle) {
        results = [results[0] items];
    }
    [self pushLibraryResults:results withOffset:offset toWatch:watch type:request_type];
}

- (void)pushLibraryResults:(NSArray *)results withOffset:(NSInteger)offset toWatch:(PBWatch *)watch type:(MPMediaGrouping)type {
    NSArray* subset;
    if(offset < [results count]) {
        NSInteger count = MAX_RESPONSE_COUNT;
        if([results count] <= offset + MAX_RESPONSE_COUNT) {
            count = [results count] - offset;
        }
        subset = [results subarrayWithRange:NSMakeRange(offset, count)];
    }
    NSMutableData *result = [[NSMutableData alloc] init];
    // Response format: header of one byte containing library data type, two bytes containing
    // the total number of results, and two bytes containing our current offset. Little endian.
    // This is followed by a sequence of entries, which consist of one length byte followed by UTF-8 data
    // (pascal style)
    uint8_t type_byte = (uint8_t)type;
    uint16_t metabytes[] = {[results count], offset};
    // Include the type of library
    [result appendBytes:&type_byte length:1];
    [result appendBytes:metabytes length:4];
    for (MPMediaItemCollection* item in subset) {
        NSString *value;
        if([item isKindOfClass:[MPMediaPlaylist class]]) {
            value = [item valueForProperty:MPMediaPlaylistPropertyName];
        } else {
            value = [[item representativeItem] valueForProperty:[MPMediaItem titlePropertyForGroupingType:type]];
        }
        if([value length] > MAX_LABEL_LENGTH) {
            value = [value substringToIndex:MAX_LABEL_LENGTH];
        }
        NSData *value_data = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        uint8_t length = [value_data length];
        if([result length] + length > MAX_OUTGOING_SIZE) break;
        [result appendBytes:&length length:1];
        [result appendData:value_data];
        NSLog(@"Value: %@", value);
    }
    // Send it!
    [watch appMessagesPushUpdate:@{IPOD_LIBRARY_RESPONSE_KEY: result} onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
        if(error) {
            NSLog(@"Error sending library response: %@", error);
        }
    }];
    NSLog(@"Sent message: %@", result);
}

@end
