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
#import "SBServer.h"


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
    oldURL = server.url;
    oldUsername = server.username;
    oldPassword = server.password;
}

- (void)closeSheet:(id)sender {
    [super closeSheet:sender];
    
    // XXX: Not sure if PW updates MOC, since PW is not in Core Data anymore
    if([self.managedObjectContext hasChanges] || ![self.server.password isEqualToString: oldPassword]) {
        NSURL *oldURLAsURL = [NSURL URLWithString: oldURL];
        [self.server updateKeychainWithOldURL: oldURLAsURL oldUsername: oldUsername];
        [self.managedObjectContext commitEditing];
        [self.managedObjectContext save:nil];
    }
}

- (void)cancelSheet:(id)sender {
    [super cancelSheet:sender];
    
    if(self.server != nil && !editMode) {
        [self.managedObjectContext deleteObject:self.server];
        [self.managedObjectContext processPendingChanges];
    }
}

@end
