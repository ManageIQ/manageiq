#
# Description: This method is used to send Email Alerts based on Management System
#

def build_details(ext_management_system)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Build Email Subject
  subject = "#{alert} | vCenter: [#{ext_management_system.name}]"

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>vCenter <b>#{ext_management_system.name}</b> Properties:"
  body += "<br>Hostname: #{ext_management_system.hostname}"
  body += "<br>IP Address(es): #{ext_management_system.ipaddress}"
  body += "<br>Host Information:"
  body += "<br>Aggregate Host CPU Speed: #{ext_management_system.aggregate_cpu_speed.to_i / 1000} Ghz"
  body += "<br>Aggregate Host CPU Cores: #{ext_management_system.aggregate_cpu_total_cores}"
  body += "<br>Aggregate Host CPUs: #{ext_management_system.hardware.aggregate_physical_cpus}"
  body += "<br>Aggregate Host Memory: #{ext_management_system.aggregate_memory}"
  body += "<br>SSH Permit Root: #{ext_management_system.aggregate_vm_cpus}"
  body += "<br><br>"

  body += "<br>VM Information:"
  body += "<br>Aggregate VM Memory: #{ext_management_system.aggregate_vm_memory} bytes"
  body += "<br>Aggregate VM CPUs: #{ext_management_system.aggregate_vm_cpus} bytes"
  body += "<br><br>"

  body += "<br>Relationships:"
  body += "<br>Hosts: #{ext_management_system.total_hosts}"
  body += "<br>Datastores: #{ext_management_system.total_storages}"
  body += "<br>VM(s): #{ext_management_system.total_vms}"
  body += "<br><br>"

  body += "<br>Host Tags:"
  body += "<br>#{ext_management_system.tags.inspect}"
  body += "<br><br>"

  body += "<br>Regards,"
  body += "<br>#{signature}"

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

ext_management_system = $evm.root['ext_management_system']
build_details(ext_management_system) unless ext_management_system.nil?
