#
# Description: This method removes the stack from the VMDB database
#

stack = $evm.root['orchestration_stack']

if stack && !$evm.get_state_var('stack_exists_in_provider')
  $evm.log('info', "Removing stack <#{stack.name}> from VMDB")
  stack.remove_from_vmdb
  $evm.root['orchestration_stack'] = nil
end
