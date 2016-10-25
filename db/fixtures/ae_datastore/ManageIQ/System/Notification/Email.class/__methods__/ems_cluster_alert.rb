#
# Description: This method is used to send Email Alerts based on Cluster
#

def build_details(ems_cluster)
  signature = $evm.object['signature']

  # Set alert to alert description
  alert = $evm.root['miq_alert_description']

  # Get Appliance name from model unless specified below
  appliance = nil
  appliance ||= $evm.root['miq_server'].ipaddress

  # Build Email Subject
  subject = "#{alert} | Cluster: [#{ems_cluster.name}]"

  # Build Email Body
  body = "Attention,"
  body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
  body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
  body += "<br>Alert: #{alert}"
  body += "<br><br>"

  body += "<br>Cluster <b>#{ems_cluster.name}</b> Properties:"
  body += "<br>Cluster URL: <a href='https://#{appliance}/ems_cluster/show/"
  body += "#{ems_cluster.id}'>https://#{appliance}/ems_cluster/show/#{ems_cluster.id}</a>"
  body += "<br>Total Host CPU Resources: #{ems_cluster.aggregate_cpu_speed}"
  body += "<br>Total Host Memory: #{ems_cluster.aggregate_memory}"
  body += "<br>Total Host CPUs: #{ems_cluster.aggregate_physical_cpus}"
  body += "<br>Total Host CPU Cores: #{ems_cluster.aggregate_cpu_total_cores}"
  body += "<br>Total Configured VM Memory: #{ems_cluster.aggregate_vm_memory}"
  body += "<br>Total Configured VM CPUs: #{ems_cluster.aggregate_vm_cpus}"
  body += "<br><br>"

  body += "<br>Configuration:"
  body += "<br>HA Enabled: #{ems_cluster.ha_enabled}"
  body += "<br>HA Admit Control: #{ems_cluster.ha_admit_control}"
  body += "<br>DRS Enabled: #{ems_cluster.drs_enabled}"
  body += "<br>DRS Automation Level: #{ems_cluster.drs_automation_level}"
  body += "<br>DRS Migration Threshold: #{ems_cluster.drs_migration_threshold}"
  body += "<br><br>"

  body += "<br>Relationships:"
  body += "<br>Datacenter: #{ems_cluster.v_parent_datacenter}"
  body += "<br>Hosts: #{ems_cluster.total_hosts}"
  body += "<br>VM(s): #{ems_cluster.total_vms}"
  body += "<br><br>"

  body += "<br>Cluster Tags:"
  body += "<br>#{ems_cluster.tags.inspect}"
  body += "<br><br>"

  body += "<br>Regards,"
  body += "<br>#{signature}"

  $evm.object['body'] = body
  $evm.object['subject'] = subject
end

ems_cluster = $evm.root['ems_cluster']
build_details(ems_cluster) unless ems_cluster.nil?
