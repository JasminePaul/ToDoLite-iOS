//
//  Task.m
//  ToDo Lite
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Task.h"
#import "List.h"

#define kTaskImageName @"image"

@implementation Task

@dynamic checked, list_id, type;

+ (NSString*) docType {
    return kTaskDocType;
}

- (void) setImage: (NSData*)image contentType: (NSString*)contentType {
    [self setAttachmentNamed:kTaskImageName withContentType:contentType content:image];
}

@end
