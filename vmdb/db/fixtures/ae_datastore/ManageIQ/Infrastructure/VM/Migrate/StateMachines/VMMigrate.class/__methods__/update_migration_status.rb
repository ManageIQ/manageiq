#
# Description: This method updates the migration status
#

miq_task = $evm.root['vm_migrate_task']
status   = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok'
  if status == 'migration_complete'
    message = 'VM Migrated Successfully'
    miq_task.finished(message)
  end
  miq_task.message = status
end

# Update Status for on_error
miq_task.message = status if $evm.root['ae_result'] == 'error'
