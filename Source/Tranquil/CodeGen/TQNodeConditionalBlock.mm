#import "TQNodeConditionalBlock.h"
#import "TQNodeLoopBlock.h"
#import "../TQProgram.h"
#import "TQNodeVariable.h"
#import "TQNodeReturn.h"
#import "../TQDebug.h"
#import "TQNodeOperator.h"

using namespace llvm;

@implementation TQNodeIfBlock
@synthesize condition=_condition, elseBlockStatements=_elseBlockStatements, containingLoop=_containingLoop;

+ (TQNodeIfBlock *)node { return (TQNodeIfBlock *)[super node]; }

- (id)init
{
    if(!(self = [super init]))
        return nil;

    // If blocks don't take arguments
    [[self arguments] removeAllObjects];

    return self;
}

- (void)dealloc
{
    [_condition release];
    [super dealloc];
}

- (NSString *)_name
{
    return @"if";
}

- (NSString *)description
{
    NSMutableString *out = [NSMutableString stringWithFormat:@"<%@@ ", [self _name]];
    [out appendFormat:@"(%@)", _condition];
    [out appendString:@" {\n"];

    if(self.statements.count > 0) {
        [out appendString:@"\n"];
        for(TQNode *stmt in self.statements) {
            [out appendFormat:@"\t%@\n", stmt];
        }
    }
    if(_elseBlockStatements.count > 0) {
        [out appendString:@"}\n else {\n"];
        for(TQNode *stmt in _elseBlockStatements) {
            [out appendFormat:@"\t%@\n", stmt];
        }
    }
    [out appendString:@"}>"];
    return out;
}

- (TQNode *)referencesNode:(TQNode *)aNode
{
    TQNode *ref = nil;

    if((ref = [_condition referencesNode:aNode]))
        return ref;
    else if((ref = [self.statements tq_referencesNode:aNode]))
        return ref;
    else if((ref = [_elseBlockStatements tq_referencesNode:aNode]))
        return ref;

    return nil;
}

- (void)iterateChildNodes:(TQNodeIteratorBlock)aBlock
{
    aBlock(_condition);
    [super iterateChildNodes:aBlock];
    for(TQNode *node in _elseBlockStatements) {
        aBlock(node);
    }
}


#pragma mark - Code generation

- (llvm::Value *)generateTestExpressionInProgram:(TQProgram *)aProgram
                                     withBuilder:(IRBuilder<> *)aBuilder
                                           value:(llvm::Value *)aValue
{
    return aBuilder->CreateICmpNE(aValue, ConstantPointerNull::get(aProgram.llInt8PtrTy), "ifTest");
}

- (llvm::Value *)generateCodeInProgram:(TQProgram *)aProgram block:(TQNodeBlock *)aBlock error:(NSError **)aoErr
{
    if([aBlock isKindOfClass:[TQNodeWhileBlock class]])
        _containingLoop = (TQNodeWhileBlock *)aBlock;
    else if([aBlock isKindOfClass:[self class]] && [(TQNodeIfBlock *)aBlock containingLoop])
        _containingLoop = [(TQNodeIfBlock *)aBlock containingLoop];

    Module *mod = aProgram.llModule;

    // Pose as the parent block for the duration of code generation
    self.function = aBlock.function;
    self.autoreleasePool = aBlock.autoreleasePool;
    self.locals = aBlock.locals;

    Value *testExpr = [_condition generateCodeInProgram:aProgram block:aBlock error:aoErr];
    if(*aoErr)
        return NULL;
    Value *testResult = [self generateTestExpressionInProgram:aProgram withBuilder:aBlock.builder value:testExpr];

    BOOL hasElse = (_elseBlockStatements.count > 0);

    BasicBlock *thenBB = BasicBlock::Create(mod->getContext(), "then", aBlock.function);
    IRBuilder<> *thenBuilder = NULL;
    BasicBlock *elseBB = NULL;
    IRBuilder<> *elseBuilder = NULL;

    thenBuilder = new IRBuilder<>(thenBB);
    self.basicBlock = thenBB;
    self.builder = thenBuilder;
    for(TQNode *stmt in self.statements) {
        [stmt generateCodeInProgram:aProgram block:self error:aoErr];
        if(*aoErr)
            return NULL;
        if([stmt isKindOfClass:[TQNodeReturn class]])
            break;
    }

    if(hasElse) {
        elseBB = BasicBlock::Create(mod->getContext(), "else", aBlock.function);
        elseBuilder = new IRBuilder<>(elseBB);
        self.basicBlock = elseBB;
        self.builder = elseBuilder;
        for(TQNode *stmt in _elseBlockStatements) {
            [stmt generateCodeInProgram:aProgram block:self error:aoErr];
            if(*aoErr)
                return NULL;
        }
    }

    BasicBlock *endifBB = BasicBlock::Create(mod->getContext(), [[NSString stringWithFormat:@"end%@", [self _name]] UTF8String], aBlock.function);
    IRBuilder<> *endifBuilder = new IRBuilder<>(endifBB);

    // If our basic block has been changed that means there was a nested conditional
    // We need to fix it by adding a br pointing to the endif
    if(self.basicBlock != thenBB && self.basicBlock != elseBB) {
        BasicBlock *tailBlock = self.basicBlock;
        IRBuilder<> *tailBuilder = self.builder;

        if(!tailBlock->getTerminator())
            tailBuilder->CreateBr(endifBB);
    }
    if(!thenBB->getTerminator())
        thenBuilder->CreateBr(endifBB);
    if(elseBB && !elseBB->getTerminator())
        elseBuilder->CreateBr(endifBB);

    delete thenBuilder;
    delete elseBuilder;

    aBlock.builder->CreateCondBr(testResult, thenBB, elseBB ? elseBB : endifBB);

    // Make the parent block continue from the end of the statement
    aBlock.basicBlock = endifBB;
    aBlock.builder = endifBuilder;

    self.builder = NULL;
    self.function = NULL;

    return testResult;
}


#pragma mark - Unused methods from TQNodeBlock
- (NSString *)signature { return nil; }
- (BOOL)addArgument:(TQNodeArgumentDef *)aArgument error:(NSError **)aoError { return NO; }
- (llvm::Constant *)_generateBlockDescriptorInProgram:(TQProgram *)aProgram { return NULL; }
- (llvm::Value *)_generateBlockLiteralInProgram:(TQProgram *)aProgram parentBlock:(TQNodeBlock *)aParentBlock { return NULL; }
- (llvm::Function *)_generateCopyHelperInProgram:(TQProgram *)aProgram { return NULL; }
- (llvm::Function *)_generateDisposeHelperInProgram:(TQProgram *)aProgram { return NULL; }
- (llvm::Function *)_generateInvokeInProgram:(TQProgram *)aProgram error:(NSError **)aoErr { return NULL; }
- (llvm::Type *)_blockDescriptorTypeInProgram:(TQProgram *)aProgram { return NULL; }
- (llvm::Type *)_genericBlockLiteralTypeInProgram:(TQProgram *)aProgram { return NULL; }
- (llvm::Type *)_blockLiteralTypeInProgram:(TQProgram *)aProgram { return NULL; }
@end

@implementation TQNodeUnlessBlock
- (llvm::Value *)generateTestExpressionInProgram:(TQProgram *)aProgram
                                     withBuilder:(IRBuilder<> *)aBuilder
                                           value:(llvm::Value *)aValue
{
    return aBuilder->CreateICmpEQ(aValue, ConstantPointerNull::get(aProgram.llInt8PtrTy), "unlessTest");
}
- (NSString *)_name
{
    return @"unless";
}
@end

@implementation TQNodeTernaryOperator
@synthesize ifExpr=_ifExpr, elseExpr=_elseExpr;

+ (TQNodeTernaryOperator *)node
{
    return (TQNodeTernaryOperator *)[super node];
}

+ (TQNodeTernaryOperator *)nodeWithIfExpr:(TQNode *)aIfExpr else:(TQNode *)aElseExpr
{
    TQNodeTernaryOperator *ret = [self node];
    ret.ifExpr = aIfExpr;
    ret.elseExpr = aElseExpr;
    return ret;
}

- (llvm::Value *)generateCodeInProgram:(TQProgram *)aProgram block:(TQNodeBlock *)aBlock error:(NSError **)aoErr
{
    TQAssert(_ifExpr, @"Ternary operator missing truth result");
    TQNodeVariable *tempVar = [TQNodeVariable new];
    [tempVar createStorageInProgram:aProgram block:aBlock error:aoErr];

    TQNodeOperator *ifAsgn  = [TQNodeOperator nodeWithType:kTQOperatorAssign left:tempVar right:_ifExpr];
    self.statements = [NSArray arrayWithObject:ifAsgn];

    if(_elseExpr) {
        TQNodeOperator *elseAsgn  = [TQNodeOperator nodeWithType:kTQOperatorAssign left:tempVar right:_elseExpr];
        self.elseBlockStatements = [NSArray arrayWithObject:elseAsgn];
    }
    [super generateCodeInProgram:aProgram block:aBlock error:aoErr];

    [tempVar release];
    return [tempVar generateCodeInProgram:aProgram block:aBlock error:aoErr];
}

- (TQNode *)referencesNode:(TQNode *)aNode
{
    TQNode *ref;
    if((ref = [self.condition referencesNode:aNode]))
        return ref;
    else if((ref = [_ifExpr referencesNode:aNode]))
        return ref;
    return [_elseExpr referencesNode:aNode];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ternary@ (%@) ? %@ : %@>", self.condition, _ifExpr, _elseExpr];
}
@end
