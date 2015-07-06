#
# Description: This method is used to send Email Alerts based on Management System
#

def buildDetails(ext_management_system)
  # Build options Hash
  options = {}

  options[:object] = "vCenter - #{ext_management_system.name}"

  # Set alert to alert description
  options[:alert] = $evm.root['miq_alert_description']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  # Build Email Subject
  subject = "#{options[:alert]} | vCenter: [#{ext_management_system.name}]"
  options[:subject] = subject

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{options[:alert]}"
  body += "<br><br>"

  body += "<br>vCenter <b>#{ext_management_system.name}</b> Properties:"
  body += "<br>Hostname: #{ext_management_system.hostname}"
  body += "<br>IP Address(es): #{ext_management_system.ipaddress}"
  body += "<br>Host Information:"
  body += "<br>Aggregate Host CPU Speed: #{ext_management_system.aggregate_cpu_speed.to_i / 1000} Ghz"
  body += "<br>Aggregate Host CPU Cores: #{ext_management_system.aggregate_logical_cpus}"
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
  to  ||= $evm.object['to_email_address']

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

ext_management_system = $evm.root['ext_management_system']
unless ext_management_system.nil?
  $evm.log("info", "Detected Host:<#{host.name}>")

  # If email is set to true in the model
  options = buildDetails(ext_management_system)

  # Get email from model
  email = $evm.object['email']

  if boolean(email)
    emailAlert(options)
  end

end
