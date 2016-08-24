#
# Description: This method is used to send Email Alerts based on Host
#

def build_details(host)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Get Appliance name from model unless specified below
  appliance = nil
  # appliance ||= $evm.object['appliance']
  appliance ||= $evm.root['miq_server'].ipaddress

  # Build Email Subject
  subject = "#{alert} | Host: [#{host.name}]"

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>Host <b>#{host.name}</b> Properties:"
  body += "<br>Host URL: <a href='https://"
  body += "#{appliance}/host/show/#{host.id}'>https://#{appliance}/host/show/#{host.id}</a>"
  body += "<br>Hostname: #{host.hostname}"
  body += "<br>IP Address(es): #{host.ipaddress}"
  body += "<br>CPU Type: #{host.hardware.cpu_type}"
  body += "<br>Cores per Socket: #{host.hardware.cpu_total_cores}"
  body += "<br>vRAM: #{host.hardware.memory_mb.to_i / 1024} GB"
  body += "<br>Operating System: #{host.vmm_product} #{host.vmm_version} Build #{host.vmm_buildnumber}"
  body += "<br>SSH Permit Root: #{host.ssh_permit_root_login}"
  body += "<br><br>"

  body += "<br>Power Maangement:"
  body += "<br>Power State: #{host.power_state}"
  body += "<br><br>"

  body += "<br>Relationships:"
  body += "<br>Datacenter: #{host.v_owning_datacenter}"
  body += "<br>Cluster: #{host.v_owning_cluster}"
  body += "<br>Datastores: #{host.v_total_storages}"
  body += "<br>VM(s): #{host.v_total_vms}"
  body += "<br><br>"

  body += "<br>Host Tags:"
  body += "<br>#{host.tags.inspect}"
  body += "<br><br>"

  body += "<br>Regards,"
  body += "<br>#{signature}"
  options[:body] = body

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

host = $evm.root['host']
build_details(host) unless host.nil?
