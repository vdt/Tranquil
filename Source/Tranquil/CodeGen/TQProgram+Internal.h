// Defines private methods and those that require a C++ compiler (So that client apps don't need to be compiled as ObjC++ even if they only perform basic execution)

#import <Tranquil/CodeGen/TQProgram.h>
#import <Tranquil/CodeGen/TQProgram+LLVMUtils.h>
#include <llvm/IRBuilder.h>
#include <llvm/DIBuilder.h>
#include <llvm/ExecutionEngine/JIT.h>
#include <llvm/ExecutionEngine/JITMemoryManager.h>
#include <llvm/ExecutionEngine/JITEventListener.h>
#include <llvm/ExecutionEngine/GenericValue.h>

#define DW_LANG_Tranquil 0x9c40
#define TRANQUIL_DEBUG_DESCR "Tranquil α"

@class TQNodeRootBlock, NSString, NSError;

@interface TQProgram () {
    llvm::ExecutionEngine *_executionEngine;
}
@property(readonly) NSMutableArray *evaluatedPaths; // Reset after root finishes

@property(readonly) llvm::Module *llModule;

#pragma mark - Global values
@property(readonly) llvm::GlobalVariable *globalQueue;

#pragma mark - Debug info related
@property(readonly) llvm::DIBuilder *debugBuilder;

- (TQNodeRootBlock *)_rootFromFile:(NSString *)aPath error:(NSError **)aoErr;
- (TQNodeRootBlock *)_parseScript:(NSString *)aScript withPath:(NSString *)aPath error:(NSError **)aoErr;
- (NSString *)_resolveImportPath:(NSString *)aPath;

- (void)insertLogUsingBuilder:(llvm::IRBuilder<> *)aBuilder withStr:(NSString *)txt;
- (llvm::Value *)getGlobalStringPtr:(NSString *)aStr withBuilder:(llvm::IRBuilder<> *)aBuilder;
- (llvm::Value *)getGlobalStringPtr:(NSString *)aStr inBlock:(TQNodeBlock *)aBlock;
- (llvm::Value *)getSelector:(NSString *)aSelector inBlock:(TQNodeBlock *)aBlock root:(TQNodeRootBlock *)aRoot;
- (llvm::Value *)getSelector:(NSString *)aSelector withBuilder:(llvm::IRBuilder<> *)aBuilder root:(TQNodeRootBlock *)aRoot;
@end

