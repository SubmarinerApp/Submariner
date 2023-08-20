//
//  SBEditServerController.m
//  Submariner
//
//  Created by Rafaël Warnault on 06/06/11.
//  Copyright 2011 Read-Write.fr. All rights reserved.
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

#import "SBEditServerController.h"
#import "SBWindowController.h"

#import "Submariner-Swift.h"


@implementation SBEditServerController

@synthesize server;
@synthesize editMode;

@synthesize oldURL, oldPassword, oldUsername;

- (SBServer*)server {
    return server;
}

- (void)setServer:(SBServer *)newServer {
    server = newServer;
    if (self.server == nil) {
        return;
    }
    oldName = server.resourceName;
    oldURL = server.url;
    oldUsername = server.username;
    oldPassword = server.password;
    oldToken = server.useTokenAuth;
}

- (void)closeSheet:(id)sender {
    // make sure things make sense so we don't deal with some bizarre sitch
    // FIXME: other validations possible; i believe SBServer does this for resourceName already
    if (!server.resourceName || [server.resourceName isEqualToString: @""]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Invalid Server Name";
        alert.informativeText = @"The server name can't be empty.";
        [alert runModal];
        return;
    }
    if (!server.url || [server.url isEqualToString: @""]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Invalid URL";
        alert.informativeText = @"The URL can't be empty.";
        [alert runModal];
        return;
    } else if ([NSURLComponents componentsWithString: server.url] == nil) {
        // TODO: Is this overly strict?
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Invalid URL";
        alert.informativeText = @"The URL isn't valid. It should be a full URL including the protocol, hostname, and if needed, port.";
        [alert runModal];
        return;
    }
    // username and password must be passed to subsonic, but allowed to be empty in theory
    
    // finally finished validations
    [super closeSheet:sender];
    
    // XXX: Not sure if PW updates MOC, since PW is not in Core Data anymore
    if ([self.managedObjectContext hasChanges] || ![self.server.password isEqualToString: oldPassword]) {
        if (self.oldURL) {
            NSURL *oldURLAsURL = [NSURL URLWithString: oldURL];
            [self.server updateKeychainWithOldURL: oldURLAsURL oldUsername: oldUsername];
        } else {
            // For a new server
            [self.server updateKeychainPassword];
        }
        [self.managedObjectContext commitEditing];
        [self.managedObjectContext save:nil];
    }
    
    // Invalidate the server's parameters since it could have changed (i.e. token)
    // ...which is held by the client controller owned by the server.
    // easiest way to do that is to force a reconnect
    [server connect];
}

- (void)cancelSheet:(id)sender {
    [super cancelSheet:sender];
    
    if(self.server != nil && !editMode) {
        [self.managedObjectContext deleteObject:self.server];
        [self.managedObjectContext processPendingChanges];
    } else if (self.server != nil) {
        // XXX: MOC undo unreliable; should be a transaction?
        self.server.resourceName = oldName;
        self.server.url = oldURL;
        self.server.username = oldUsername;
        self.server.password = oldPassword;
        self.server.useTokenAuth = oldToken;
        [self.managedObjectContext commitEditing];
        [self.managedObjectContext save:nil];
    }
}

@end
