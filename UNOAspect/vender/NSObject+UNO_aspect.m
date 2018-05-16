//
//  NSObject+UNO_aspect.m
//  UNOAspect
//
//  Created by intebox on 2018/5/10.
//  Copyright © 2018年 unovo. All rights reserved.
//

#import "NSObject+UNO_aspect.h"
#import <objc/runtime.h>
#import <objc/message.h>



#define aspect_aliasForSelector(selector)\
(!NSStringFromSelector(selector)?NULL:NSSelectorFromString(\
[_Aspect_SEL_Prefix stringByAppendingString:\
NSStringFromSelector(selector)]))

@interface UNOAspectToken()

@property (nonatomic, assign) SEL from;
@property (nonatomic, readonly) SEL fromAlias;

@property (nonatomic, strong) NSMapTable <NSString* ,id>*tos;

@end

@implementation UNOAspectToken

static NSString *_Aspect_SEL_Prefix = @"_Aspect_SEL_Prefix";
- (SEL)fromAlias{
    if (self.from == NULL) return NULL;
    return aspect_aliasForSelector(self.from);
}

- (NSMapTable<NSString *,id> *)tos{
    if (!_tos) {
        _tos = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                                     valueOptions:NSPointerFunctionsWeakMemory];
    }
    return _tos;
}

- (NSString *)description{
    NSMutableString *des = [NSMutableString string];
    [des appendString:@"{"];
    [des appendFormat:@"from: %@,\nalias:%@\n",NSStringFromSelector(self.from),NSStringFromSelector(self.fromAlias)];
    for (NSString *selName in self.tos.keyEnumerator.allObjects) {
        [des appendFormat:@"sel: %@,target:%@\n",selName,[self.tos objectForKey:selName]];
    }
    [des appendString:@"}\n"];
    return des.copy;
}

@end

@implementation NSObject (UNO_aspect)

- (UNOAspectToken *)aspect_fromSelector:(SEL)from to:(SEL)to{
   return [self aspect_fromSelector:from toTarget:self to:to];
}

- (UNOAspectToken *)aspect_fromSelector:(SEL)from toTarget:(id)toTarget to:(SEL)to{
    NSString *fromSelName = NSStringFromSelector(from);
    NSString *toSelName = NSStringFromSelector(to);
    if (!fromSelName ||!toSelName || !toTarget) {
        return nil;
    }
    
    return aspect_NSObjectForSelector(self, from, to,toTarget);
}

static UNOAspectToken *aspect_NSObjectForSelector(NSObject *self, SEL from,SEL to,id toTarget){
    
    NSMapTable *store = _aspect_tokenStore(self);
    UNOAspectToken *token = [store objectForKey:NSStringFromSelector(from)];
    if (token){
        if ([token.tos.keyEnumerator.allObjects containsObject:NSStringFromSelector(to)]) return nil;
        [token.tos setObject:toTarget forKey:NSStringFromSelector(to)];
        return token;
    }else{
        token = [[UNOAspectToken alloc] init];
        token.from = from;
        [token.tos setObject:toTarget forKey:NSStringFromSelector(to)];
    }
    
    SEL fromAlias = token.fromAlias;
    if (fromAlias == NULL) return nil;
    
    @synchronized(self){
        Class class = _aspect_swizzleClass(self);
        if (!class) return nil;
        
        Method targetMethod = class_getInstanceMethod(class, token.from);
        
        if (targetMethod == NULL) return nil;
        
        IMP targetMethodImp = method_getImplementation(targetMethod);
        if (targetMethodImp!= _objc_msgForward) {
            const char *typeEncoding = method_getTypeEncoding(targetMethod);
            class_addMethod(class,token.fromAlias,targetMethodImp,typeEncoding);
            class_replaceMethod(class, token.from, _objc_msgForward, typeEncoding);
            [_aspect_tokenStore(self) setObject:token
                                         forKey:NSStringFromSelector(from)];
            
            return token;
        }
    }
    return nil;
}

#pragma mark-
#pragma mark- subClass
static const char *_Aspect_SubClass_Key = "_Apect_SubClass_Key";
static NSString *Aspect_SubclassSuffix = @"_Aspect_MT";
static Class _aspect_swizzleClass(NSObject *self){
    Class statedClass = self.class;
    Class baseClass = object_getClass(self);
    
    Class aspect_subClass = objc_getAssociatedObject(self, _Aspect_SubClass_Key);
    
    if (aspect_subClass) return aspect_subClass;
    
    NSString *className = NSStringFromClass(baseClass);
    
    if (statedClass != baseClass) {
        //It is alreadly a dynamic class for example a KVO Class
        @synchronized(self){
            if (![someClassSwizzledAlreadly() containsObject:baseClass]) {
             
                _aspect_swizzleForwardInvocation(baseClass);
                _aspect_swizzleRespondsToSelector(baseClass);
                _aspect_swizzleGetClass(baseClass, statedClass);
                _aspect_swizzleGetClass(object_getClass(baseClass), statedClass);
                _aspect_swizzleMethodSignatureForSelector(baseClass);
                [someClassSwizzledAlreadly() addObject:baseClass];
            }
        }
        return baseClass;
    }
    
    const char *subclassName = [className stringByAppendingString:Aspect_SubclassSuffix].UTF8String;
    Class subclass = objc_getClass(subclassName);
    
    if (subclass == nil) {
        subclass = objc_allocateClassPair(baseClass, subclassName, 0);
        if (!subclass) return nil;
        
        _aspect_swizzleForwardInvocation(subclass);
        _aspect_swizzleRespondsToSelector(subclass);
        _aspect_swizzleGetClass(subclass,statedClass);
        _aspect_swizzleGetClass(object_getClass(subclass),statedClass);
        _aspect_swizzleMethodSignatureForSelector(subclass);
        
        objc_registerClassPair(subclass);
    }
    
    object_setClass(self, subclass);
    objc_setAssociatedObject(self, _Aspect_SubClass_Key, subclass, OBJC_ASSOCIATION_ASSIGN);
    return subclass;
}

static void _aspect_swizzleForwardInvocation(Class class){
    SEL forwardInvocationSEL = @selector(forwardInvocation:);
    Method forwardInvocationMethod = class_getInstanceMethod(class, forwardInvocationSEL);
    void (*originalForwardInvocation)(id, SEL, NSInvocation *) = NULL;
    
    if (forwardInvocationMethod != NULL) {
        originalForwardInvocation = (__typeof__(originalForwardInvocation))method_getImplementation(forwardInvocationMethod);
    }
    
    id newForwardInvocation = ^(id self,NSInvocation *invocation){
        if (_aspect_forwardInvocation(self, invocation)) return;
        
        if (originalForwardInvocation == NULL) {
            [self doesNotRecognizeSelector:invocation.selector];
        }else{
            originalForwardInvocation(self,forwardInvocationSEL,invocation);
        }
    };
    
    class_replaceMethod(class,forwardInvocationSEL,
                        imp_implementationWithBlock(newForwardInvocation),
                        method_getTypeEncoding(forwardInvocationMethod));
}

static void _aspect_swizzleRespondsToSelector(Class class){
    SEL respondsToSelectorSEL = @selector(respondsToSelector:);
    
    Method respondsToSeletorMethod = class_getInstanceMethod(class, respondsToSelectorSEL);
    
    BOOL(*originalRespondsToSelector)(id,SEL,SEL) = (__typeof(originalRespondsToSelector))method_getImplementation(respondsToSeletorMethod);
    
    id newRespondsToSelector = ^BOOL(id self,SEL selector){
        Method method = _aspect_matchInstanceMethod(class,selector);
        if (method != NULL &&
            method_getImplementation(method) == _objc_msgForward) {
            if (objc_getAssociatedObject(self,_Aspect_SubClass_Key)!=nil) return true;
        }
        
        return originalRespondsToSelector(self, respondsToSelectorSEL, selector);
    };
    
    class_replaceMethod(class,respondsToSelectorSEL,
                        imp_implementationWithBlock(newRespondsToSelector),
                        method_getTypeEncoding(respondsToSeletorMethod));
}

static void _aspect_swizzleGetClass(Class class, Class statedClass){
    SEL classSEL = @selector(class);
    Method ClassMethod = class_getInstanceMethod(class, classSEL);
    IMP getClassImp = imp_implementationWithBlock(^(id self){
        return statedClass;
    });
    class_replaceMethod(class,classSEL,getClassImp,
                        method_getTypeEncoding(ClassMethod));
}

static void _aspect_swizzleMethodSignatureForSelector(Class class){
    
    SEL methodSignatureSEL = @selector(methodSignatureForSelector:);
    NSMethodSignature *(^selectorNilHandler)(void) = ^NSMethodSignature *{
        return nil;
    };
    
    id newMethodSignatureImp = (NSMethodSignature *)^(id self, SEL selector){
        if (selector == nil) {
            return  selectorNilHandler();
        }
        //不要[self class],这个方法的实现已经被我们替换了
        Class realClass = object_getClass(self);
        Method targetMethod = class_getInstanceMethod(realClass, selector);
        if (targetMethod == NULL) {
            struct objc_super target = {
                .receiver = self,
                .super_class = class_getSuperclass(realClass),
            };
         
            NSMethodSignature *(*messageSend)(struct objc_super *,SEL,SEL) = (__typeof__(messageSend))objc_msgSendSuper;
            return messageSend(&target,methodSignatureSEL,selector);
        }
        
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        return [NSMethodSignature signatureWithObjCTypes:typeEncoding];
    };
    
    Method methodSignatureMethod = class_getInstanceMethod(class, methodSignatureSEL);
    IMP methodSignatureImp = imp_implementationWithBlock(newMethodSignatureImp);
    const char *typeEncoding = method_getTypeEncoding(methodSignatureMethod);
    class_replaceMethod(class, methodSignatureSEL, methodSignatureImp, typeEncoding);
}

#pragma mark-
#pragma mark- implementation
static BOOL _aspect_forwardInvocation(id self,NSInvocation *invocation){

    //do not to use token.fromalias
    //the token maybe realeased because of it is weak memoried by maptable
    SEL originalSel = invocation.selector;
    SEL aliasSel = aspect_aliasForSelector(originalSel);
    Class class = object_getClass(invocation.target);
    BOOL canRespondToSel = [class instancesRespondToSelector:aliasSel];
    if (canRespondToSel) {
        invocation.selector = aliasSel;
        [invocation invoke];
    }

    UNOAspectToken *token = [_aspect_tokenStore(self) objectForKey:NSStringFromSelector(originalSel)];
    
    if (!token) return canRespondToSel;
    
    for (NSString *to in token.tos.keyEnumerator.allObjects) {
        SEL toSel= NSSelectorFromString(to);
        id toTarget= [token.tos objectForKey:to];
        Class toClass = object_getClass(toTarget);
        if ([toClass instancesRespondToSelector:toSel]) {
            NSMethodSignature *methodSignature = [toTarget methodSignatureForSelector:toSel];

            if (methodSignature  == nil||
                methodSignature.numberOfArguments != invocation.methodSignature.numberOfArguments)
                continue;
            
            NSInvocation *toInvocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            toInvocation.target = toTarget;
            toInvocation.selector = toSel;
            NSUInteger argumentCount = invocation.methodSignature.numberOfArguments;
            for (int i=2 ; i<argumentCount; i++) {
                void *argument = NULL;
                const char *type = [invocation.methodSignature getArgumentTypeAtIndex:i];
                NSUInteger argSize;
                NSGetSizeAndAlignment(type, &argSize, NULL);
                if (!(argument = reallocf(argument, argSize))) {
                    NSLog(@"fail to memory alloc");
                    continue;
                }
                
                [invocation getArgument:argument atIndex:i];
                [toInvocation setArgument:argument atIndex:i];
            }
            [toInvocation invoke];
        }
    }
    
    return canRespondToSel;
}

#pragma mark-
#pragma mark- util

static Method _aspect_matchInstanceMethod(Class class,SEL selector){
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(class, &methodCount);
    Method target = NULL;
    
    for (int i = 0; i<methodCount; i++) {
        Method method = methods[methodCount];
        if (method_getName(method) == selector) {
            target = method;
            break;
        }
    }
    free(methods);
    return target;
}

#pragma mark-
#pragma mark- store
static const char *_Aspect_TokenStore_key = "_Aspect_TokenStore_key";
static NSMapTable *_aspect_tokenStore(id self){
    NSMapTable *store = (NSMapTable *)objc_getAssociatedObject(self, _Aspect_TokenStore_key);
    
    if (!store) {
        store = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                                      valueOptions:NSPointerFunctionsStrongMemory];
        objc_setAssociatedObject(self, _Aspect_TokenStore_key, store, OBJC_ASSOCIATION_RETAIN);
    }
    return store;
}

static NSHashTable* someClassSwizzledAlreadly(){
    static NSHashTable *one = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        one = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
    });
    return one;
}

@end
