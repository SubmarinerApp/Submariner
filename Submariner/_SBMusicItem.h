// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBMusicItem.h instead.

#import <CoreData/CoreData.h>









@interface SBMusicItemID : NSManagedObjectID {}
@end

@interface _SBMusicItem : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBMusicItemID*)objectID;



@property (nonatomic, strong) NSNumber *isLocal;

@property BOOL isLocalValue;
- (BOOL)isLocalValue;
- (void)setIsLocalValue:(BOOL)value_;

//- (BOOL)validateIsLocal:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *id;

//- (BOOL)validateId:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *itemName;

//- (BOOL)validateItemName:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *path;

//- (BOOL)validatePath:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSNumber *isLinked;

@property BOOL isLinkedValue;
- (BOOL)isLinkedValue;
- (void)setIsLinkedValue:(BOOL)value_;

//- (BOOL)validateIsLinked:(id*)value_ error:(NSError**)error_;





@end

@interface _SBMusicItem (CoreDataGeneratedAccessors)

@end

@interface _SBMusicItem (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveIsLocal;
- (void)setPrimitiveIsLocal:(NSNumber*)value;

- (BOOL)primitiveIsLocalValue;
- (void)setPrimitiveIsLocalValue:(BOOL)value_;




- (NSString*)primitiveId;
- (void)setPrimitiveId:(NSString*)value;




- (NSString*)primitiveItemName;
- (void)setPrimitiveItemName:(NSString*)value;




- (NSString*)primitivePath;
- (void)setPrimitivePath:(NSString*)value;




- (NSNumber*)primitiveIsLinked;
- (void)setPrimitiveIsLinked:(NSNumber*)value;

- (BOOL)primitiveIsLinkedValue;
- (void)setPrimitiveIsLinkedValue:(BOOL)value_;




@end
