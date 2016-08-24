#
# Description: This method is used to send Email Alerts based on VM
#
def build_details(vm)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Get Appliance name from model unless specified below
  appliance = nil
  appliance ||= $evm.root['miq_server'].ipaddress

  # Build Email Subject
  subject = "#{alert} | VM: [#{vm.name}]"

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>VM <b>#{vm.name}</b> Properties:"
  body += "<br>VM URL: <a href='https://#{appliance}/VM/show/#{vm.id}'>https://#{appliance}/VM/show/#{vm.id}</a>"
  body += "<br>Hostname: #{vm.hostnames.inspect}"
  body += "<br>IP Address(es): #{vm.ipaddresses.inspect}"
  body += "<br>vCPU: #{vm.cpu_total_cores}"
  body += "<br>vRAM: #{vm.mem_cpu.to_i} MB"
  body += "<br>Tools Status: #{vm.tools_status}"
  body += "<br>Operating System: #{vm.operating_system['product_name']}"
  body += "<br>Disk Alignment: #{vm.disks_aligned}"
  body += "<br><br>"

  body += "<br>Power Maangement:"
  body += "<br>Power State: #{vm.power_state}"
  body += "<br>Last Boot: #{vm.boot_time}"
  body += "<br><br>"

  body += "<br>Snapshot Information:"
  body += "<br>Total Snapshots: #{vm.v_total_snapshots}"
  body += "<br>Total Snapshots: #{vm.v_total_snapshots}"
  body += "<br><br>"

  body += "<br>Relationships:"
  body += "<br>Datacenter: #{vm.v_owning_datacenter}"
  body += "<br>Cluster: #{vm.ems_cluster_name}"
  body += "<br>Host: #{vm.host_name}"
  body += "<br>Datastore Path: #{vm.v_datastore_path}"
  body += "<br>Resource Pool: #{vm.v_owning_resource_pool}"
  body += "<br><br>"

  body += "<br>VM Tags:"
  body += "<br>#{vm.tags.inspect}"
  body += "<br><br>"

  body += "<br>Regards,"
  body += "<br>#{signature}"

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

vm = $evm.root['vm']
build_details(vm) unless vm.nil?
