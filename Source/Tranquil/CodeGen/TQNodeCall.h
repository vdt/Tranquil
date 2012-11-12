#import <Tranquil/CodeGen/TQNode.h>

// A call to a block (block: argument.)
@interface TQNodeCall : TQNode
@property(readwrite, retain) TQNode *callee;
@property(readwrite, retain) OFMutableArray *arguments;
+ (TQNodeCall *)nodeWithCallee:(TQNode *)aCallee;
- (id)initWithCallee:(TQNode *)aCallee;

- (llvm::Value *)generateCodeInProgram:(TQProgram *)aProgram block:(TQNodeBlock *)aBlock root:(TQNodeRootBlock *)aRoot
                         withArguments:(std::vector<llvm::Value*>)aArgs error:(TQError **)aoErr;
@end
