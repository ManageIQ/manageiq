#
# Description: Set finished message for provision object.
#

task = $evm.root[$evm.inputs['object']]
task.finished($evm.inputs['message'])
