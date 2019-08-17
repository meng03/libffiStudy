# libffiStudy
学习libffi

这几天看了下[BlockHook](https://github.com/yulingtianxia/BlockHook)库，里面有用到libffi，这里学习一下。
#### 动态调用函数的基础
一个函数的调用，在汇编代码中，会先将参数放到指定的寄存器，或者栈中，然后call这个方法的标签。方法执行时，会去寄存器或者栈中取参数来执行。
按照这个原理，我们只要拿到函数名字符串，参数类型和返回值类型就可以调用这个函数了。
* 直接处理参数到寄存器或者栈中
* 根据函数名取到函数指针
* 调用函数指针。

#### `libffi`的功能
##### 动态调用函数
要我们自己通过汇编去处理这些，就太复杂了，但是又有动态化调用的需求。幸好有`libffi`帮我们处理这些复杂问题。
`libffi`调用有三个步骤
* 使用`ffi_type`处理参数和返回值类型
* 根据参数和返回值类型与个数，构建函数模版`cif`。
* 根据构建的模版与真实参数，调用函数指针。

````
//准备参数类型
ffi_type **types;  // 参数类型
types = malloc(sizeof(ffi_type *) * 2) ;
types[0] = &ffi_type_sint;
types[1] = &ffi_type_sint;
ffi_type *retType = &ffi_type_sint;
//准备模版
ffi_cif cif;
ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, retType, types);
//调用
ffi_call(&cif, fun1,  &ret, args);
````
##### block相关操作
除了调用函数，`libffi`还有处理`block`的功能。
````
//Allocate a chunk of memory holding size bytes. This returns a pointer to the writable address, and sets *code to the corresponding executable address.
void *ffi_closure_alloc (size_t size, void **code)
//Prepare a closure function.
 ffi_status ffi_prep_closure_loc (ffi_closure *closure, ffi_cif *cif, void (*fun) (ffi_cif *cif, void *ret, void **args, void *user_data), void *user_data, void *codeloc)
````
第一个函数，文档描述是分配一块内存，返回这块内存的可写入地址，设置code的地址为这块地址的可执行位置。没怎么读明白
第二个函数做了什么事呢。文档描述的也不太清楚。
还是直接写代码debug来看吧
先写一个符合第二个函数fun参数格式的函数备用。
````
static void closureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    printf("closureFunc");
}
````

然后就按照之前介绍的步骤处理参数，返回值，函数模版`cif`。
````
//准备参数类型
ffi_type **types;
types = malloc(sizeof(ffi_type *) * 2) ;
types[0] = &ffi_type_sint;
types[1] = &ffi_type_sint;
//返回值类型
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
````
先在`ffi_closure_alloc`函数执行之后断点，看看这个函数执行后，closure和imp的变化。
![图片发自简书App](http://upload-images.jianshu.io/upload_images/1431064-5e0ac95a6db699da.jpg)


从断点来看，imp的地址与closure是一样的。
在最后再断一次点来看看。
![图片发自简书App](http://upload-images.jianshu.io/upload_images/1431064-a437072b3a7e9be6.jpg)

`closure`中填充了函数参数中的`cif`和`closureFunc`。
`imp`仍然指向`closure`。
````
void **args = malloc(sizeof(void *) * 2);
int x = 1, y = 2;
args[0] = &x;
args[1] = &y;
int ret;
ffi_call(&cif, imp, &ret, args);
````
构造下参数和返回值，调用下这个imp。断点走到了我们准备的函数`closureFunc`中，并且带上了所有的参数，以及返回值类型。
那逻辑就比较明显了。imp -> closure -> fun

通过这两个函数，将imp指向了fun函数。下面根据代码执行情况对这两个方法做了注释。
````
/**
 分配一块内存，返回内参地址，并将code也指向这块地址。

 @param size 分配的内参大小
 @param code 指向这块内存
 @return 这块内存的地址
 */
void *ffi_closure_alloc (size_t size, void **code);
````
````
/**
 用函数模版cif,函数指针fun，填充ffi_closure

 @param ffi_closure ffi_closure_alloc函数创建的closure
 @param ffi_cif 函数模版cif
 @param fun 要绑定的函数
 @return 返回绑定状态
 */
ffi_status
ffi_prep_closure_loc (ffi_closure*,
		      ffi_cif *,
		      void (*fun)(ffi_cif*,void*,void**,void*),
		      void *user_data,
		      void*codeloc);
````

那这个功能的使用场景是什么呢？看下下面的代码。

````
int (^block)(int, int) = ^(int x, int y) {
        int result = x + y;
        return result;
    };
    //将block的invoke指向imp
    ((__bridge struct _Block *)block)->invoke = imp;
    //调用block
    block(1,2);
````
我们将block的invoke指向了这个处理过的imp，然后调用block。于是我们就在我们的函数中拿到了block的全部参数，这里我们还可以保存下block的invoke，这样，我们就可以在函数中先执行一些代码，在执行原invoke，在执行一些代码。是的，我们可以hook这个block了。具体如何Hook一个block，大家可以看[BlockHook](https://github.com/yulingtianxia/BlockHook)库。

[上边用到的完整代码](https://github.com/meng03/libffiStudy)
