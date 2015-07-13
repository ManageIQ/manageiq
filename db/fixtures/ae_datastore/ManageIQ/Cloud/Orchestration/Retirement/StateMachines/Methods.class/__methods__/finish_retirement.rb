#
# Description: This method marks the stack as retired
#

stack = $evm.root['orchestration_stack']
stack.finish_retirement if stack
