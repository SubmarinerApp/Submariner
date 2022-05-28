// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBIndex.h instead.

#import <CoreData/CoreData.h>
#import "SBMusicItem.h"

@class SBServer;


@interface SBIndexID : NSManagedObjectID {}
@end

@interface _SBIndex : SBMusicItem {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBIndexID*)objectID;




@property (nonatomic, strong) SBServer* server;
//- (BOOL)validateServer:(id*)value_ error:(NSError**)error_;




@end

@interface _SBIndex (CoreDataGeneratedAccessors)

@end

@interface _SBIndex (CoreDataGeneratedPrimitiveAccessors)



- (SBServer*)primitiveServer;
- (void)setPrimitiveServer:(SBServer*)value;


@end
