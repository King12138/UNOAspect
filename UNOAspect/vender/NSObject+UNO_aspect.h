//
//  NSObject+UNO_aspect.h
//  UNOAspect
//
//  Created by intebox on 2018/5/10.
//  Copyright © 2018年 unovo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UNOAspectToken:NSObject

@end

@interface NSObject (UNO_aspect)

//aspect hook a selector and send to the object's another method
- (UNOAspectToken *)aspect_fromSelector:(SEL)from to:(SEL)to;

//aspect hook a selector and send to the another object
//if toTarget is not self, you should make toTarget as you property and strong it
//will not strong the toTarget for ao avoid circular reference
- (UNOAspectToken *)aspect_fromSelector:(SEL)from toTarget:(id)toTarget to:(SEL)to;

@end


