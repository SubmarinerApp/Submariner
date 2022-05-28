// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBResource.h instead.

#import <CoreData/CoreData.h>


@class SBSection;




@interface SBResourceID : NSManagedObjectID {}
@end

@interface _SBResource : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBResourceID*)objectID;



@property (nonatomic, strong) NSNumber *index;

@property int indexValue;
- (int)indexValue;
- (void)setIndexValue:(int)value_;

//- (BOOL)validateIndex:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *resourceName;

//- (BOOL)validateResourceName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) SBSection* section;
//- (BOOL)validateSection:(id*)value_ error:(NSError**)error_;




@end

@interface _SBResource (CoreDataGeneratedAccessors)

@end

@interface _SBResource (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveIndex;
- (void)setPrimitiveIndex:(NSNumber*)value;

- (int)primitiveIndexValue;
- (void)setPrimitiveIndexValue:(int)value_;




- (NSString*)primitiveResourceName;
- (void)setPrimitiveResourceName:(NSString*)value;





- (SBSection*)primitiveSection;
- (void)setPrimitiveSection:(SBSection*)value;


@end
