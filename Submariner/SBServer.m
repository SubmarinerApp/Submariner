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
#import "SBAppDelegate.h"

#include "NSString+Hex.h"
#include "NSString+File.h"
#include "NSURL+Parameters.h"

@implementation SBServer

@dynamic resources;
@synthesize clientController;
@synthesize selectedTabIndex;
@synthesize cachedPassword;


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
    NSImage *result = [NSImage imageNamed: NSImageNameStatusUnavailable];
    
    if([self.isValidLicense boolValue])
        result = [NSImage imageNamed: NSImageNameStatusAvailable];
    
    return result;
}


#pragma mark -
#pragma mark Custom Accessors (Rename Directories)

- (void) setResourceName:(NSString *)resourceName {
    // The covers directory should be renamed, since it uses resource name.
    [self willChangeValueForKey:@"resourceName"];
    // Rename here, since we can get changed by the edit server controller or source list,
    // so there's no bottleneck where we can place it.
    // XXX: Refactor to avoid having to keep doing this?
    NSString *oldName = [self primitiveResourceName];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *coversDir = [[SBAppDelegate sharedInstance] coverDirectory];
    NSString *oldDir = [coversDir stringByAppendingPathComponent: oldName];
    // If we're renaming a new server that has no content, it won't have a dir yet.
    // If the directory name does make sense though, do try a rename.
    if ([oldName isValidFileName]
        && [resourceName isValidFileName]
        && ![oldName isEqualToString: resourceName]
        && ![resourceName isEqualToString: @"Local Library"] // avoid stepping on local covers
        && [fm fileExistsAtPath: oldDir]) {
        NSString *newDir = [coversDir stringByAppendingPathComponent: resourceName];
        NSError *error = nil;
        // Tie our success to if we moved the directory. If we let this get out of sync,
        // it'll be very annoying for the user, while not fatal.
        if ([fm moveItemAtPath: oldDir toPath: newDir error: &error]) {
            [self setPrimitiveResourceName: resourceName];
        } else {
            [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
        }
    } else if ([resourceName isValidFileName] && ![resourceName isEqualToString: @"Local Library"]) {
        // If we're renaming a new server that has no content, it won't have a dir yet.
        // No directory stuff to try, but do make sure we don't have an invalid name.
        [self setPrimitiveResourceName: resourceName];
    }
    [self didChangeValueForKey:@"resourceName"];
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

    if (self.primitivePassword && ![self.primitivePassword isEqualToString: @""]) {
        [self setPassword: self.primitivePassword];
        // assuming it's successful
        string = cachedPassword;
    } else if (self.cachedPassword) {
        string = cachedPassword;
    } else if(self.url && self.username) {

        NSURL *anUrl = [NSURL URLWithString:self.url];
        
        // get internet keychain
        NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
        attribs[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
        attribs[(__bridge id)kSecAttrServer] = anUrl.host;
        attribs[(__bridge id)kSecAttrAccount] = self.username;
        attribs[(__bridge id)kSecAttrPath] = @"/";
        attribs[(__bridge id)kSecAttrPort] = [anUrl portWithHTTPFallback];
        attribs[(__bridge id)kSecAttrProtocol] = [anUrl keychainProtocol];
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
            [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
        } else {
            NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
            NSData *passwordData = [resultDict valueForKey: (id)kSecValueData];
            string = [[NSString alloc] initWithData: passwordData encoding: NSUTF8StringEncoding];
            cachedPassword = string;
        }
    }
    [self didAccessValueForKey: @"password"];
    return string;
}

- (void)updateKeychainPassword {
    NSURL *anUrl = [NSURL URLWithString:self.url];
    
    // add internet keychain
    NSLog(@"add internet keychain");
    
    // This uses the stored password set by setPassword.
    NSData *passwordData = [self.cachedPassword dataUsingEncoding: NSUTF8StringEncoding] ?: [NSData data];
    NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
    attribs[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
    attribs[(__bridge id)kSecAttrServer] = anUrl.host;
    attribs[(__bridge id)kSecAttrAccount] = self.username;
    attribs[(__bridge id)kSecAttrPath] = @"/";
    attribs[(__bridge id)kSecAttrPort] = [anUrl portWithHTTPFallback];
    attribs[(__bridge id)kSecAttrProtocol] = [anUrl keychainProtocol];
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
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    }
}

- (void)updateKeychainWithOldURL: (NSURL*)oldURL oldUsername: (NSString*)oldUsername {
    NSURL *newURL = [NSURL URLWithString: self.url];
    NSData *passwordData = [self.cachedPassword dataUsingEncoding: NSUTF8StringEncoding] ?: [NSData data];
    
    NSLog(@"update internet keychain");
    
    // The old values are used since they're what's in the keychain,
    // but the object has been changed, so it's the source of the new values.
    // We just need the username and URL, since the old PW doesn't matter in query.
    NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
    attribs[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    attribs[(__bridge id)kSecAttrServer] = oldURL.host;
    attribs[(__bridge id)kSecAttrAccount] = oldUsername;
    attribs[(__bridge id)kSecAttrPath] = @"/";
    attribs[(__bridge id)kSecAttrPort] = [oldURL portWithHTTPFallback];
    attribs[(__bridge id)kSecAttrProtocol] = [oldURL keychainProtocol];
    
    NSMutableDictionary *newAttributes = [NSMutableDictionary dictionary];
    newAttributes[(__bridge id)kSecAttrServer] = newURL.host;
    newAttributes[(__bridge id)kSecAttrAccount] = self.username;
    newAttributes[(__bridge id)kSecAttrPort] = [newURL portWithHTTPFallback];
    newAttributes[(__bridge id)kSecAttrProtocol] = [newURL keychainProtocol];
    newAttributes[(__bridge id)kSecValueData] = passwordData;
    
    OSStatus ret = SecItemUpdate((__bridge CFDictionaryRef)attribs, (__bridge CFDictionaryRef)newAttributes);
    if (ret == errSecItemNotFound) {
        // Use the old method of having it be updated by the current values,
        // since we have nothing to update. This will create it in keychain.
        [self updateKeychainPassword];
    } else if (ret != errSecSuccess) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo: nil];
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    }
}

- (void)setPassword:(NSString *) x {
    [self willChangeValueForKey: @"password"];
    // XXX: should we invalidate the stored pw?
    self.cachedPassword = nil;

    // decompose URL
    if(self.url && self.username) {
        // don't do the keychain update here anymore
        cachedPassword = x;
        // clear out the remnant of Core Data stored password
        self.primitivePassword = @"";
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
    BOOL usePasswordAuth = !self.useTokenAuthValue;
    if (usePasswordAuth) {
        [parameters removeObjectForKey: @"t"];
        [parameters removeObjectForKey: @"s"];
        [parameters setValue:[@"enc:" stringByAppendingString:[NSString stringToHex: self.password]] forKey:@"p"];
    } else {
        [parameters removeObjectForKey: @"p"];
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
