#
# Description: This method is used to send Email Alerts based on VM
#
def buildDetails(vm)
  # Build options Hash
  options = {}

  options[:object] = "VM - #{vm.name}"

  # Set alert to alert description
  options[:alert] = $evm.root['miq_alert_description']

  # Get Appliance name from model unless specified below
  appliance = nil
  # appliance ||= $evm.object['appliance']
  appliance ||= $evm.root['miq_server'].ipaddress

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  # Build Email Subject
  subject = "#{options[:alert]} | VM: [#{vm.name}]"
  options[:subject] = subject

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{options[:alert]}"
  body += "<br><br>"

  body += "<br>VM <b>#{vm.name}</b> Properties:"
  body += "<br>VM URL: <a href='https://#{appliance}/VM/show/#{vm.id}'>https://#{appliance}/VM/show/#{vm.id}</a>"
  body += "<br>Hostname: #{vm.hostnames.inspect}"
  body += "<br>IP Address(es): #{vm.ipaddresses.inspect}"
  body += "<br>vCPU: #{vm.logical_cpus}"
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
  options[:body] = body

  # Return options Hash with subject, body, alert
  options
end

def boolean(string)
  return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
  return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)
  false
end

def emailAlert(options)
  # Get to_email_address from model unless specified below
  to = nil
  to ||= $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get subject from options Hash
  subject = options[:subject]

  # Get body from options Hash
  body = options[:body]

  $evm.log("info", "Sending email To:<#{to}> From:<#{from}> subject:<#{subject}>")
  $evm.execute(:send_email, to, from, subject, body)
end

vm = $evm.root['vm']
unless vm.nil?
  $evm.log("info", "Detected VM:<#{vm.name}>")

  # If email is set to true in the model
  options = buildDetails(vm)

  # Get email from model
  email = $evm.object['email']

  if boolean(email)
    emailAlert(options)
  end
end
