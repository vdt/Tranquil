#import "TQBlockNamingProcessor.h"
#import "../TQNodeOperator.h"
#import "../TQNodeMethod.h"
#import "../TQNodeMessage.h"
#import "../TQNodeVariable.h"
#import "../TQNodeArgument.h"
#import "../TQNodeNil.h"
#import "../TQNodeConditionalBlock.h"
#import "../TQNodeCall.h"
#import "../TQNodeMessage.h"

@implementation TQBlockNamingProcessor
+ (void)load
{
    if(self != [TQBlockNamingProcessor class])
        return;
    [TQProcessor registerProcessor:self];
}

+ (TQNode *)processNode:(TQNode *)aNode withTrace:(OFArray *)aTrace
{
    if(![aNode isKindOfClass:[TQNodeBlock class]] || [aNode isKindOfClass:[TQNodeMethod class]])
        return aNode;
    TQNodeBlock *blk = (TQNodeBlock *)aNode;
    TQNode *parent = [aTrace lastObject];
    OFString *name = nil;
    if([parent isKindOfClass:[TQNodeAssignOperator class]])
        name = [[[(TQNodeAssignOperator *)parent left] objectAtIndex:0] toString];
    else if([parent isKindOfClass:[TQNodeCall class]])
        name = [OFString stringWithFormat:@"%@_blkArg", [parent toString]];
    else if([parent isKindOfClass:[TQNodeArgument class]]) {
        TQNode *grandParent = [aTrace objectAtIndex:[aTrace count] - 2];
        if([grandParent isKindOfClass:[TQNodeMessage class]])
            name = [OFString stringWithFormat:@"%@_blkArg", [grandParent toString]];
    }

    if(name)
        blk.invokeName = [OFString stringWithFormat:@"__tq_%@", name];
    return aNode;
}
@end
