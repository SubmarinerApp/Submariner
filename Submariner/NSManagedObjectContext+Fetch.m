//
//  NSManagedObjectContext+Fetch.m
//  Sub
//
//  Created by Rafaël Warnault on 15/05/11.
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

#import "NSManagedObjectContext+Fetch.h"


@implementation NSManagedObjectContext (Fetch)

- (NSArray *)fetchEntitiesNammed:(NSString *)name withPredicate:(NSPredicate *)predicate error:(NSError **)error {
    //NSError *error = nil;
	
    NSArray *ret = nil;
    
    @synchronized(self) {
        NSFetchRequest *request;
        NSEntityDescription *desc;
        
        desc = [NSEntityDescription entityForName:name inManagedObjectContext:self];
        request = [[NSFetchRequest alloc] init];
        
        [request setEntity:desc];
        if(predicate)
            [request setPredicate:predicate];
        
        ret = [self executeFetchRequest:request error:error];	
    }
    return ret;	
}


- (id)fetchEntityNammed:(NSString *)name withPredicate:(NSPredicate *)predicate error:(NSError **)error {
    id ret = nil;
    
    @synchronized(self) {
        NSArray *entities = nil;
        NSFetchRequest *request;
        NSEntityDescription *desc;
        
        desc = [NSEntityDescription entityForName:name inManagedObjectContext:self];
        request = [[NSFetchRequest alloc] init];
        
        [request setEntity:desc];
        if(predicate)
            [request setPredicate:predicate];
        
        entities = [self executeFetchRequest:request error:error];	
        
        if(entities && [entities count] > 0) {
            ret = [entities objectAtIndex:0];
        }
    }
    return ret;
}


@end
