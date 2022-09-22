//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



#import "SBServer.h"
#import "SBHome.h"
#import "SBClientController.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBPlaylist.h"

#include "NSString+Hex.h"

@implementation SBServer

@dynamic resources;
@synthesize clientController;
@synthesize selectedTabIndex;


+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *result = nil;
    
    if([key isEqualToString:@"playlists"]) {
        result = [NSSet setWithObjects:@"resources", nil];
    }
    
    if([key isEqualToString:@"resources"]) {
        result = [NSSet setWithObjects:@"playlists", nil];
    }
    
    if([key isEqualToString:@"licenseImage"]) {
        result = [NSSet setWithObjects:@"isValidLicense", nil];
    }
    
    return result;
}



#pragma mark -
#pragma mark LifeCycle


- (void)awakeFromInsert {
    [super awakeFromInsert];
    if(self.home == nil) {
        self.home = [SBHome insertInManagedObjectContext:self.managedObjectContext];
    }

}




#pragma mark -
#pragma mark Custom Accessors (Source List Tree Support)

- (NSSet *)resources {
    NSSet *result = nil;
    
    [self willAccessValueForKey:@"resources"];
    [self willAccessValueForKey:@"playlists"];
    
    result = [self primitiveValueForKey:@"playlists"];
    
    [self didAccessValueForKey:@"playlists"];
    [self didAccessValueForKey:@"resources"];
    
    return result;
}

- (void)setResources:(NSSet *)_resources {
    
    [self willChangeValueForKey:@"resources"];
    [self willChangeValueForKey:@"playlists"];
    
    [self setPrimitiveValue:_resources forKey:@"playlists"];
    
    [self didChangeValueForKey:@"playlists"];
    [self didChangeValueForKey:@"resources"];
}

- (NSSet *)playlists {
    NSSet *result = nil;
    
    [self willAccessValueForKey:@"resources"];
    [self willAccessValueForKey:@"playlists"];
    
    result = [self primitiveValueForKey:@"playlists"];
    
    [self didAccessValueForKey:@"playlists"];
    [self didAccessValueForKey:@"resources"];
    
    return result;
}

- (void)setPlaylists:(NSSet *)playlistsSet {
    
    [self willChangeValueForKey:@"resources"];
    [self willChangeValueForKey:@"playlists"];
    
    [self setPrimitiveValue:playlistsSet forKey:@"playlists"];
    
    [self didChangeValueForKey:@"playlists"];
    [self didChangeValueForKey:@"resources"];
}



- (NSImage *)licenseImage {
    NSImage *result = [NSImage imageNamed:@"off"];
    
    if([self.isValidLicense boolValue])
        result = [NSImage imageNamed:@"on"];
    
    return result;
}


#pragma mark -
#pragma mark Custom Accessors (Subsonic Client)

- (SBClientController *)clientController {
    if(!clientController) {
        clientController = [[SBClientController alloc] initWithManagedObjectContext:self.managedObjectContext];
        [clientController setServer:self];
    }
    
    return clientController;
}




#pragma mark -
#pragma mark Custom Accessors (Keychain Support)

- (NSString *)password {

    NSString *string = nil;
    [self willAccessValueForKey: @"password"];

    // decompose URL
    if(self.url && self.username) {

        NSURL *anUrl = [NSURL URLWithString:self.url];
        // protocol scheme
        uint protocol = kSecProtocolTypeHTTP;
        if([[anUrl scheme] rangeOfString:@"s"].location != NSNotFound) {
            protocol = kSecProtocolTypeHTTPS;
        }
        // url port
        NSNumber *port = [NSNumber numberWithInteger: protocol == kSecProtocolTypeHTTPS ? 443 : 80];
        if([anUrl port] != nil) {
            port = [anUrl port];
        }

        // get internet keychain
        // XXX: Caching?
        NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
        attribs[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
        attribs[(__bridge id)kSecAttrServer] = anUrl.host;
        attribs[(__bridge id)kSecAttrAccount] = self.username;
        attribs[(__bridge id)kSecAttrPath] = @"/";
        attribs[(__bridge id)kSecAttrPort] = anUrl.port;
        attribs[(__bridge id)kSecAttrProtocol] = [NSNumber numberWithInt: protocol];
            // query only
        attribs[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        attribs[(__bridge id)kSecReturnData] = [NSNumber numberWithBool: YES];
        attribs[(__bridge id)kSecReturnAttributes] = [NSNumber numberWithBool: YES];
        CFDictionaryRef result = nil;
        OSStatus ret = SecItemCopyMatching((__bridge CFDictionaryRef)attribs, (CFTypeRef *)&result);
        if (ret == errSecItemNotFound) {
            string = nil;
        } else if (ret != errSecSuccess) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo: nil];
            NSLog(@"%@", error);
        } else {
            NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
            NSData *passwordData = [resultDict valueForKey: (id)kSecValueData];
            string = [[NSString alloc] initWithData: passwordData encoding: NSUTF8StringEncoding];
        }
    }
    [self didAccessValueForKey: @"password"];
    return string;
}

- (void)setPassword:(NSString *) x {
    [self willChangeValueForKey: @"password"];

    // decompose URL
    if(self.url && self.username) {
        NSURL *anUrl = [NSURL URLWithString:self.url];
        // protocol scheme
        uint protocol = kSecProtocolTypeHTTP;
        if([[anUrl scheme] rangeOfString:@"s"].location != NSNotFound) {
            protocol = kSecProtocolTypeHTTPS;
        }
        // url port
        NSNumber *port = [NSNumber numberWithInteger: protocol == kSecProtocolTypeHTTPS ? 443 : 80];
        if([anUrl port] != nil) {
            port = [anUrl port];
        }

        // add internet keychain
        NSLog(@"add internet keychain");
        
        // get internet keychain
        NSData *passwordData = [x dataUsingEncoding: NSUTF8StringEncoding];
        NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
        attribs[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
        attribs[(__bridge id)kSecAttrServer] = anUrl.host;
        attribs[(__bridge id)kSecAttrAccount] = self.username;
        attribs[(__bridge id)kSecAttrPath] = @"/";
        attribs[(__bridge id)kSecAttrPort] = anUrl.port;
        attribs[(__bridge id)kSecAttrProtocol] = [NSNumber numberWithInt: protocol];
        attribs[(__bridge id)kSecValueData] = passwordData;
        OSStatus ret = SecItemAdd((__bridge CFDictionaryRef)attribs, NULL);
        if (ret == errSecDuplicateItem) {
            [attribs removeObjectForKey: (__bridge id)kSecValueData];
            NSDictionary *updateAttribs = @{
                (__bridge id)kSecValueData: passwordData,
            };
            ret = SecItemUpdate((__bridge CFDictionaryRef)attribs, (__bridge CFDictionaryRef)updateAttribs);
        }
        
        if (ret != errSecSuccess) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo: nil];
            NSLog(@"%@", error);
        }
    }
    [self didChangeValueForKey: @"password"];
}

#pragma mark -
#pragma mark Subsonic Client (Login)

- (void)connect {
    [[self clientController] connectToServer:self];
}

- (void)getServerLicense {
    [[self clientController] getLicense];
}

- (void)getBaseParameters: (NSMutableDictionary*)parameters
{
    [parameters setValue: self.username forKey:@"u"];
    // it seems navidrome lets use use tokens even with an old declared API.
    BOOL usePasswordAuth = NO;
    if (usePasswordAuth) {
        [parameters setValue:[@"enc:" stringByAppendingString:[NSString stringToHex: self.password]] forKey:@"p"];
    } else {
        NSMutableData *salt_bytes = [NSMutableData dataWithLength: 64];
        int rc = SecRandomCopyBytes(kSecRandomDefault, 64, [salt_bytes mutableBytes]);
        if (rc != 0) {
            // XXX: we are having a bad day
        }
        NSString *salt = [NSString stringFromBytes: salt_bytes];
        [parameters setValue: salt forKey:@"s"];
        NSString *password = self.password;
        NSString *token = [[NSString stringWithFormat: @"%@%@", password, salt] md5];
        [parameters setValue: token forKey:@"t"];
    }
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"apiVersion"] forKey:@"v"];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"clientIdentifier"] forKey:@"c"];
}




#pragma mark -
#pragma mark Subsonic Client (Server Data)

- (void)getServerIndexes {
    if(self.lastIndexesDate != nil) {
        [[self clientController] getIndexesSince:self.lastIndexesDate];
    } else {
        [[self clientController] getIndexes];
    }
}

- (void)getAlbumsForArtist:(SBArtist *)artist {
    [[self clientController] getAlbumsForArtist:artist];
}

- (void)getTracksForAlbumID:(NSString *)albumID {
    [[self clientController] getTracksForAlbumID:albumID];
}

- (void)getAlbumListForType:(SBSubsonicRequestType)type {
    [[self clientController] getAlbumListForType:type];
}




#pragma mark -
#pragma mark Subsonic Client (Playlists)

- (void)getServerPlaylists {
    [[self clientController] getPlaylists];
}

- (void)createPlaylistWithName:(NSString *)playlistName tracks:(NSArray *)tracks {
    [[self clientController] createPlaylistWithName:playlistName tracks:tracks];
}

- (void)updatePlaylistWithID:(NSString *)playlistID tracks:(NSArray *)tracks {
    [[self clientController] updatePlaylistWithID:playlistID tracks:tracks];
}

- (void)deletePlaylistWithID:(NSString *)playlistID {
    [[self clientController] deletePlaylistWithID:playlistID];
}

- (void)getPlaylistTracks:(SBPlaylist *)playlist {
    [[self clientController] getPlaylist:playlist];
}




#pragma mark -
#pragma mark Subsonic Client (Podcasts)

- (void)getServerPodcasts {
   [[self clientController] getPodcasts]; 
}



#pragma mark -
#pragma mark Subsonic Client (Now Playing)

- (void)getNowPlaying {
    [[self clientController] getNowPlaying];
}




#pragma mark -
#pragma mark Subsonic Client (Search)

- (void)searchWithQuery:(NSString *)query {
    [[self clientController] search:query];
}




#pragma mark -
#pragma mark Subsonic Client (Rating)

- (void)setRating:(NSInteger)rating forID:(NSString *)anID {
    [[self clientController] setRating:rating forID:anID];
}



@end
