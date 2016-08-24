#
# Description: This method is used to send Email Alerts based on Datastore
#

def build_details(storage)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Get Appliance name from model unless specified below
  appliance = nil
  # appliance ||= $evm.object['appliance']
  appliance ||= $evm.root['miq_server'].ipaddress

  # Build Email Subject
  subject = "#{alert} | Datastore: [#{storage.name}]"

  # Build Email Body
  body = "Attention, "
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>Storage <b>#{storage.name}</b> Properties:"
  body += "<br>Storage URL: <a href='https://#{appliance}/Storage/show/"
  body += "#{storage.id}'>https://#{appliance}/Storage/show/#{storage.id}</a>"
  body += "<br>Type: #{storage.store_type}"
  body += "<br>Free Space: #{storage.free_space.to_i / (1024**3)} GB (#{storage.v_free_space_percent_of_total}%)"
  body += "<br>Used Space: #{storage.v_used_space.to_i / (1024**3)} GB (#{storage.v_used_space_percent_of_total}%)"
  body += "<br>Total Space: #{storage.total_space.to_i / (1024**3)} GB"
  body += "<br><br>"

  body += "<br>Information for Registered VMs:"
  body += "<br>Used + Uncommitted Space: #{storage.v_total_provisioned.to_i / (1024**3)} "
  body += "GB (#{storage.v_provisioned_percent_of_total}%)"
  body += "<br><br>"

  body += "<br>Content:"
  body += "<br>VM Provisioned Disk Files: #{storage.disk_size.to_i / (1024**3)} GB (#{storage.v_disk_percent_of_used}%)"
  body += "<br>VM Snapshot Files: #{storage.snapshot_size.to_i / (1024**3)} GB (#{storage.v_snapshot_percent_of_used}%)"
  body += "<br>VM Memory Files: #{storage.v_total_memory_size.to_i / (1024**3)} "
  body += "GB (#{storage.v_memory_percent_of_used}%)"
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

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

storage = $evm.root['storage']
build_details(storage) unless storage.nil?
