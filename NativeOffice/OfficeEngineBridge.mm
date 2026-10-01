#import "OfficeEngineBridge.h"
#include <COKit/COKitInit.h>
#include <memory>
#include <exception>

extern "C" {
#include "native-code.h"
}

@implementation HashiyaOfficeEngine
+ (NSError *)conversionErrorForSource:(NSURL *)source output:(NSURL *)output {
    @autoreleasepool {
        bool mayRemoveOutput = false;
        auto fail = [&](NSString *message) {
            if (mayRemoveOutput) [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            return [NSError errorWithDomain:@"HashiyaOfficeEngine" code:1
                userInfo:@{NSLocalizedDescriptionKey: message}];
        };
        if (!source.isFileURL || !output.isFileURL || [source isEqual:output])
            return fail(@"تعذّر إعداد نسخة PDF مستقلة.");
        // Refuse replacement: conversion is never a write back to the source.
        if ([[NSFileManager defaultManager] fileExistsAtPath:output.path])
            return fail(@"ملف PDF الناتج موجود بالفعل.");
        mayRemoveOutput = true;
        try {
            static COKit *office = nullptr;
            if (!office) {
                NSString *bundle = NSBundle.mainBundle.bundlePath;
                if (![[NSFileManager defaultManager] fileExistsAtPath:[bundle stringByAppendingPathComponent:@"fundamentalrc"]])
                    return fail(@"موارد محرك Office غير متاحة في هذه النسخة.");
                office = cok_init_2(nullptr, nullptr);
            }
            if (!office) return fail(@"تعذّر تشغيل محرك Office المحلي.");
            std::unique_ptr<COKitDocument> document(office->documentLoadWithOptions(
                source.absoluteString.UTF8String,
                "Language=en-US,Batch=true,EnableMacrosExecution=false,MacroSecurityLevel=3"));
            if (!document || !document->saveAs(output.absoluteString.UTF8String, "pdf", nullptr)) {
                NSString *detail = [NSString stringWithUTF8String:office->getError().c_str()];
                return fail(detail.length ? detail : @"تعذّر تحويل هذا المستند إلى PDF.");
            }
            return (NSError *)nil;
        } catch (const std::exception &exception) {
            return fail([NSString stringWithUTF8String:exception.what()] ?: @"تعذّر تحويل المستند.");
        } catch (...) {
            return fail(@"تعذّر تحويل المستند.");
        }
    }
}
@end
