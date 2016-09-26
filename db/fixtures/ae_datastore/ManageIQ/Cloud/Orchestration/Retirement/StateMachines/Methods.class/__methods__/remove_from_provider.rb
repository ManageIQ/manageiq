#
# Description: This method removes the stack from the provider
#

# Get stack from root object
stack = $evm.root['orchestration_stack']

if stack
  ems = stack.ext_management_system
  if stack.raw_exists?
    $evm.log('info', "Removing stack:<#{stack.name}> from provider:<#{ems.try(:name)}>")
    stack.raw_delete_stack
    $evm.set_state_var('stack_exists_in_provider', true)
  else
    $evm.log('info', "Stack <#{stack.name}> no longer exists in provider:<#{ems.try(:name)}>")
    $evm.set_state_var('stack_exists_in_provider', false)
  end
end
