#import "TQBlockClosure.h"
#import "TQFFIType.h"
#import "../Runtime/TQRuntime.h"
#import "TQBoxedObject.h"
#import "bs.h"

static void _closureFunction(ffi_cif *closureCif, void *ret, void *args[], TQBlockClosure *closureObj);

@implementation TQBlockClosure
@synthesize functionPointer=_functionPointer;

- (id)initWithBlock:(id)aBlock type:(const char *)aType
{
    assert(*aType == _MR_C_LAMBDA_B);
    aType += 2;
    _type = aType;

    _block = aBlock;

    ffi_closure *closure = (ffi_closure *)ffi_closure_alloc(sizeof(ffi_closure), &_functionPointer);
    if(closure) {
        const char *typeIterator = _type;
        _ffiTypeObjects = [NSMutableArray new];
        TQFFIType *retTypeObj = [TQFFIType typeWithEncoding:typeIterator nextType:&typeIterator];
        [_ffiTypeObjects addObject:retTypeObj];
        while(typeIterator && *typeIterator != _MR_C_LAMBDA_E) {
            [_ffiTypeObjects addObject:[TQFFIType typeWithEncoding:typeIterator nextType:&typeIterator]];
        }

        ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
        unsigned int nargs = [_ffiTypeObjects count] - 1;
        ffi_type **argTypes = (ffi_type**)malloc(sizeof(void*)*nargs);
        for(int i = 0; i < nargs; ++i) {
            argTypes[i] = [[_ffiTypeObjects objectAtIndex:i+1] ffiType];
        }

        if(ffi_prep_cif(cif, FFI_DEFAULT_ABI, nargs, [retTypeObj ffiType], argTypes) == FFI_OK) {
            if(ffi_prep_closure_loc(closure, cif, (void (*)(ffi_cif*,void*,void**,void*))_closureFunction, self, _functionPointer) == FFI_OK)
                objc_setAssociatedObject(_block, (void*)_cif, self, OBJC_ASSOCIATION_RETAIN);
        }
    }
    return self;
}

- (void)dealloc
{
    ffi_closure_free(_closure);
    free(_cif);
    [_ffiTypeObjects release];

    [super dealloc];
}
@end

void _closureFunction(ffi_cif *closureCif, void *ret, void *args[], TQBlockClosure *closureObj)
{
    // Construct an ffi call to the block that forwards the arguments passed to the closure
    TQBlockLiteral *block = (TQBlockLiteral *)closureObj->_block;
    unsigned int nargs = closureCif->nargs + 1;
    ffi_type *retType = &ffi_type_pointer;
    ffi_type *argTypes[nargs];
    void     *argPtrs[nargs];

    const char *returnType = closureObj->_type;
    const char *typeEncoding = TQGetSizeAndAlignment(returnType, NULL, NULL);

    argTypes[0] = &ffi_type_pointer;
    argPtrs[0]  = (id*)&block;
    id argValues[closureCif->nargs];
    for(int i = 1; i <= closureCif->nargs; ++i) {
        argTypes[i] = &ffi_type_pointer;
        argValues[i-1] = [TQBoxedObject box:args[i-1] withType:typeEncoding];
        argPtrs[i] = &argValues[i-1];
        typeEncoding = TQGetSizeAndAlignment(typeEncoding, NULL, NULL);
    }

    // Call the block
    ffi_cif callCif;
    if(ffi_prep_cif(&callCif, FFI_DEFAULT_ABI, nargs, retType, argTypes) != FFI_OK) {
        // TODO: be more graceful
        NSLog(@"unable to wrap block call");
        exit(1);
    }
    id retPtr;
    ffi_call(&callCif, FFI_FN(block->invoke), &retPtr, argPtrs);

    if(*returnType == _C_ID)
        *(id*)ret = retPtr;
    else if(*returnType != _C_VOID)
        [TQBoxedObject unbox:retPtr to:ret usingType:returnType];
}