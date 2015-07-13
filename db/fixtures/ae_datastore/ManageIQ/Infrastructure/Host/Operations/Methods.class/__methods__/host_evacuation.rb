#
# Description: When a VM encounters high CPU % Ready, VMotion VM to a more
# suitable host.
#

def emailresults(vmname, current_host, target_host)
  # Get to_email_address from model unless specified below
  to = nil
  to ||= $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']
  subject = "Alert! EVM will be VMotioning VM: #{vmname}"

  body  = "Hello, "
  body += "<br>"
  body += "EVM will VMotion VM: <b>#{vmname}</b> from current Host: <b>#{current_host}</b> to target Host: <b>#{target_host}</b>."
  body += "<br><br>"
  body += "Thank You,"
  body += "<br><br>"
  body += "#{signature}"
  body += "<br>"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute('send_email', to, from, subject, body)
end

# Initialize variables
host = $evm.root['host']
raise "Host object not found" if host.nil?
$evm.log("info", "Inspecting host object: <#{host.inspect}>")

esxhost_scope = nil
esxhost_scope ||= $evm.object['esxhost_scope']

# Get the VC
if esxhost_scope && esxhost_scope.downcase == "cluster"
  ems = host.ems_cluster
  $evm.log("info", "ESX Scope will limited to hosts in Cluster")
else
  ems = host.ext_management_system
  $evm.log("info", "ESX Scope will limited to hosts in Virtual Center")
end

# Get hosts attached to the VC
hosts = ems.hosts

# Loop through all hosts
host_suspects = hosts.select { |h| h.power_state == 'on' && h.name != host.name }

host_all = []

host_suspects.each do |h|
  host_cpu_percent = h.get_realtime_metric(:v_pct_cpu_ready_delta_summation, [15.minutes.ago.utc, 5.minutes.ago.utc], :avg)
  host_all << {:id => h.id, :percent => host_cpu_percent, :type => :cpu}
  $evm.log("info", "ESX Host: <#{h.name}> CPU Ready Delta Summation: <#{host_cpu_percent}>")
end

host_all.sort! { |a, b| a[:percent] <=> b[:percent] }

target_host = host_suspects.detect { |h| h.id == host_all.first[:id] }

# Get a list of all VM's on the current host
vms = host.vms.find_all

vms.each do |v|

  # Email Results
  emailresults(v.name, target_host.name, host.name)

  $evm.log("info", "VM: <#{v.name}> on Host: <#{host.name}> will be moved to target ESX Host: <#{target_host.name}>")
  # VMotion VM to Target_host
  v.migrate(target_host)
end
