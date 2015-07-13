#
# Description: This method is used to parse incoming automation requests
#

cur = $evm.object
cur['target_component'], cur['target_class'], cur['target_instance'] =
  case cur['request']
  when 'vm_provision'   then %w(VM   Lifecycle Provisioning)
  when 'vm_retired'     then %w(VM   Lifecycle Retirement)
  when 'vm_migrate'     then %w(VM   Lifecycle Migrate)
  when 'host_provision' then %w(Host Lifecycle Provisioning)
  when 'configured_system_provision'
    $evm.root['ae_provider_category'] = 'infrastructure'
    %w(Configured_System Lifecycle Provisioning)
  end

$evm.log("info", "Request:<#{cur['request']}> Target Component:<#{cur['target_component']}> Target Class:<#{cur['target_class']}> Target Instance:<#{cur['target_instance']}>")
