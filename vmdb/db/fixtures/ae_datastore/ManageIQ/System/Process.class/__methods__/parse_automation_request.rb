###################################
#
# EVM Automate Method: parse_automation_request
#
# Notes: This method is used to parse incoming automation requests
#
###################################
cur = $evm.object
case cur['request']
when 'vm_provision'
  cur['target_component'] = 'VM'
  cur['target_class']     = 'Lifecycle'
  cur['target_instance']  = 'Provisioning'
when 'vm_retired'
  cur['target_component'] = 'VM'
  cur['target_class']     = 'Lifecycle'
  cur['target_instance']  = 'Retirement'
when 'vm_migrate'
  cur['target_component'] = 'VM'
  cur['target_class']     = 'Lifecycle'
  cur['target_instance']  = 'Migrate'
when 'host_provision'
  cur['target_component'] = 'Host'
  cur['target_class']     = 'Lifecycle'
  cur['target_instance']  = 'Provisioning'
end

$evm.log("info", "Request:<#{cur['request']}> Target Component:<#{cur['target_component']}> Target Class:<#{cur['target_class']}> Target Instance:<#{cur['target_instance']}>")
