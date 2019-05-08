//
//  LibfiiStudy.m
//  libfiiStudy
//
//  Created by 孟冰川 on 2019/5/8.
//  Copyright © 2019 孟冰川. All rights reserved.
//

#import "LibfiiStudy.h"
#import "ffi.h"
#import <objc/runtime.h>
#import <dlfcn.h>

struct _BlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct _Block
{
    void *isa;
    int flags; //flags按位存储了一些信息，可以通过上边的enum中的mask读取
    int reserved;
    void *invoke;
    struct _BHBlockDescriptor *descriptor;
};

static void closureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    printf("closureFunc");
}


@implementation ClosureStudy

-(void) closureTest {
    
    //准备参数类型
    ffi_type **types;  // 参数类型
    types = malloc(sizeof(ffi_type *) * 2) ;
    types[0] = &ffi_type_sint;
    types[1] = &ffi_type_sint;
    ffi_type *retType = &ffi_type_sint;
    //准备模版
    ffi_cif cif;
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, retType, types);
    //创建closure
    void *imp = nil;
    ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), &imp);
    //绑定closureFunc到closure上
    ffi_status status = ffi_prep_closure_loc(closure, &cif,
                                             closureFunc, (__bridge void *)(self), imp);
    if (status != FFI_OK) { return; }
    
    
    //直接调用imp
    void **args = malloc(sizeof(void *) * 2);
    int x = 1, y = 2;
    args[0] = &x;
    args[1] = &y;
    int ret;
    ffi_call(&cif, imp, &ret, args);
        
    //通过block调用imp
    int (^block)(int, int) = ^(int x, int y) {
        int result = x + y;
        return result;
    };
    //将block的invoke指向imp
    ((__bridge struct _Block *)block)->invoke = imp;
    //调用block
    block(1,2);
}

@end
