#
# Description: This method removes the stack from the provider
#

# Get stack from root object
stack = $evm.root['orchestration_stack']

$evm.set_state_var('stack_removed_from_provider', false)

if stack
  ems = stack.ext_management_system
  $evm.log('info', "Removing stack:<#{stack.name}> from provider:<#{ems.try(:name)}>")
  stack.raw_delete_stack
end
