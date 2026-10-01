#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Calls are serialized by the Swift conversion service. It supplies a
/// temporary snapshot; a separate PDF is written to the supplied URL.
@interface HashiyaOfficeEngine : NSObject
+ (nullable NSError *)conversionErrorForSource:(NSURL *)source
                                        output:(NSURL *)output
    NS_SWIFT_NAME(conversionError(source:output:));
@end
NS_ASSUME_NONNULL_END
