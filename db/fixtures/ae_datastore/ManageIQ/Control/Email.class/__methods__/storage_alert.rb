#
# Description: This method is used to send Email Alerts based on Datastore
#

def buildDetails(storage)
  # Build options Hash
  options = {}

  options[:object] = "Datastore - #{storage.name}"

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
  subject = "#{options[:alert]} | Datastore: [#{storage.name}]"
  options[:subject] = subject

  # Build Email Body
  body = "Attention, "
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{options[:alert]}"
  body += "<br><br>"

  body += "<br>Storage <b>#{storage.name}</b> Properties:"
  body += "<br>Storage URL: <a href='https://#{appliance}/Storage/show/#{storage.id}'>https://#{appliance}/Storage/show/#{storage.id}</a>"
  body += "<br>Type: #{storage.store_type}"
  body += "<br>Free Space: #{storage.free_space.to_i / (1024**3)} GB (#{storage.v_free_space_percent_of_total}%)"
  body += "<br>Used Space: #{storage.v_used_space.to_i / (1024**3)} GB (#{storage.v_used_space_percent_of_total}%)"
  body += "<br>Total Space: #{storage.total_space.to_i / (1024**3)} GB"
  body += "<br><br>"

  body += "<br>Information for Registered VMs:"
  body += "<br>Used + Uncommitted Space: #{storage.v_total_provisioned.to_i / (1024**3)} GB (#{storage.v_provisioned_percent_of_total}%)"
  body += "<br><br>"

  body += "<br>Content:"
  body += "<br>VM Provisioned Disk Files: #{storage.disk_size.to_i / (1024**3)} GB (#{storage.v_disk_percent_of_used}%)"
  body += "<br>VM Snapshot Files: #{storage.snapshot_size.to_i / (1024**3)} GB (#{storage.v_snapshot_percent_of_used}%)"
  body += "<br>VM Memory Files: #{storage.v_total_memory_size.to_i / (1024**3)} GB (#{storage.v_memory_percent_of_used}%)"
  body += "<br><br>"

  body += "<br>Relationships:"
  body += "<br>Number of Hosts attached: #{storage.v_total_hosts}"
  body += "<br>Total Number of VMs: #{storage.v_total_vms}"
  body += "<br><br>"

  body += "<br>Datastore Tags:"
  body += "<br>#{storage.tags.inspect}"
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

storage = $evm.root['storage']
unless storage.nil?
  # If email is set to true in the model
  options = buildDetails(storage)

  # Get email from model
  email = $evm.object['email']

  if boolean(email)
    emailAlert(options)
  end
end
