#
# Description: This method will find a VM that is running hot in a given cluster and
# vMotion the VM to a more desirable host within that cluster
#

def emailresults(vm_culprit, host_culprit, host_culprit_type, host_culprit_percent, target_host)
  # Get to_email_address from model unless specified below
  to = nil
  to ||= $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  subject = "Cluster Workload Manager Services"

  body  = "Hello, "
  body += "<br>"
  body += "EVM has detected high "
  if host_culprit_type == :mem
    body += "memory utilization"
  else
    body += "CPU utilization"
  end
  body += " of (#{host_culprit_percent}%) on host #{host_culprit}."
  body += "<br>"
  body += "<br>"

  body += "Moving VM <b>#{vm_culprit}</b> to target host #{target_host}"
  body += "<br><br>"
  body += "Thank You,"
  body += "<br><br>"
  body += "#{signature}"
  body += "<br>"

  # Send email
  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute('send_email', to, from, subject, body)
end

def loghost_object(h)
  # Log Host CPU average usage I.e. Host CPU Usage: <1751.69884833285>
  $evm.log("info", "Host: <#{h.name}> Average CPU Usage: <#{h.cpu_usagemhz_rate_average_avg_over_time_period}>")

  # Log Host Memory average usage I.e. Host Memory Usage: <9341.15865541251>
  $evm.log("info", "Host: <#{h.name}> Average Memory Usage: <#{h.derived_memory_used_avg_over_time_period}>")

  # Log Host CPU Speed I.e. cpu_speed: 2493
  $evm.log("info", "Host: <#{h.name}> CPU Speed: <#{h.hardware.cpu_speed}>")

  # Log Host Memory  I.e. memory_mb: 8190
  $evm.log("info", "Host: <#{h.name}> Memory: <#{h.hardware.memory_mb}>")

  # Log Current Host CPU usage I.e. cpu_usage: 366
  $evm.log("info", "Host: <#{h.name}> Current CPU Usage: <#{h.hardware.cpu_usage}>")

  # Log Current Host Memory usage I.e. memory_usage: 4690
  $evm.log("info", "Host: <#{h.name}> Memory Usage: <#{h.hardware.memory_usage}>")
end

# Initialize variables

# Set host thresholds
host_cpu_threshold = 0.6
host_mem_threshold = 0.6

# Get Cluster
ems_cluster = $evm.root['ems_cluster']
raise "EMS Cluster not found" if ems_cluster.nil?

# Log Cluster CPU usage I.e. Cluster CPU Usage: <3381.90824648164>
$evm.log("info", "Cluster: <#{ems_cluster.name}> CPU Usage: <#{ems_cluster.cpu_usagemhz_rate_average_avg_over_time_period}>")
# Log Cluster Memory usage I.e. Cluster Memory Usage: <21410.959239421>
$evm.log("info", "Cluster: <#{ems_cluster.name}> Memory Usage: <#{ems_cluster.derived_memory_used_avg_over_time_period}>")

# Get hosts attached to the cluster
hosts = ems_cluster.hosts
raise "No Hosts found on Cluster:<#{ems_cluster.name}> not found" if hosts.nil?

# Loop through all hosts
host_suspects = hosts.select { |h| h.power_state == 'on' }

host_exceeded = []
host_all = []

host_suspects.each do |h|
  loghost_object(h)

  # Get Host CPU Capacity
  host_cpu_capacity = h.hardware.cpu_speed * h.hardware.cpu_total_cores
  host_cpu_percent = (h.cpu_usagemhz_rate_average_avg_over_time_period / host_cpu_capacity)
  $evm.log("info", "Host:<#{h.name}> CPU Capacity: <#{host_cpu_capacity}> CPU Percent: <#{host_cpu_percent}>")

  host_all << {:id => h.id, :percent => host_cpu_percent, :type => :cpu}
  if host_cpu_percent >= host_cpu_threshold
    $evm.log("info", "Host: <#{h.name}> CPU Percent: <#{host_cpu_percent}> has exceeded CPU threshold: <#{host_cpu_threshold}>")
    host_exceeded << {:id => h.id, :percent => host_cpu_percent, :type => :cpu}
  else
    $evm.log("info", "Host: <#{h.name}> CPU Percent: <#{host_cpu_percent}> is within CPU threshold: <#{host_cpu_threshold}>")
  end

  host_mem_percent = (h.derived_memory_used_avg_over_time_period / h.hardware.memory_mb)
  $evm.log("info", "Host:<#{h.name}> Memory Capacity: <#{h.hardware.memory_mb}> CPU Percent: <#{host_mem_percent}>")

  host_all << {:id => h.id, :percent => host_mem_percent, :type => :mem}
  if host_mem_percent >= host_mem_threshold
    $evm.log("info", "Host: <#{h.name}> Memory percent: <#{host_mem_percent}> has exceeded Memory threshold: <#{host_mem_threshold}>")
    host_exceeded << {:id => h.id, :percent => host_mem_percent, :type => :mem}
  else
    $evm.log("info", "Host: <#{h.name}> Memory percent: <#{host_mem_percent}> is within Memory threshold: <#{host_mem_threshold}>")
  end
end

unless host_exceeded.blank?
  host_all.sort! { |a, b| a[:percent] <=> b[:percent] }
  host_exceeded.sort! { |a, b| a[:percent] <=> b[:percent] }
  host_culprit_stats = host_exceeded.pop
  host_culprit = host_suspects.detect { |h| h.id == host_culprit_stats[:id] }

  # Only include VM's that are powered on
  vm_suspects = host_culprit.vms.select { |v| v.power_state == 'on' }

  if host_culprit_stats[:type] == :mem
    vm_suspects.sort! { |a, b| a.derived_memory_used_avg_over_time_period <=> b.derived_memory_used_avg_over_time_period }
  else
    vm_suspects.sort! { |a, b| a.cpu_usagemhz_rate_average_avg_over_time_period <=> b.cpu_usagemhz_rate_average_avg_over_time_period }
  end

  vm_culprit = vm_suspects.pop
  target_host_stats = host_all.detect { |h| h[:type] == host_culprit_stats[:type] }
  target_host = host_suspects.detect { |h| h.id == target_host_stats[:id] }

  # Log VM Memory  I.e. mem_cpu: <4096>
  $evm.log("info", "VM: <#{vm_culprit.name}> Memory: <#{vm_culprit.mem_cpu}>")

  # Log VM CPU Count I.e. CPU Count: <2>
  $evm.log("info", "VM: <#{vm_culprit.name}> CPU Count: <#{vm_culprit.cpu_total_cores}>")

  # Log VM CPU average usage I.e. Average CPU Usage: <405.791768303411>
  $evm.log("info", "VM: <#{vm_culprit.name}> Average CPU Usage: <#{vm_culprit.cpu_usagemhz_rate_average_avg_over_time_period}>")

  # Log VM Memory average usage I.e. Average Memory Usage: <863.462927057142>
  $evm.log("info", "VM: <#{vm_culprit.name}> Average Memory Usage: <#{vm_culprit.derived_memory_used_avg_over_time_period}>")

  # Email the results
  host_culprit_percent = (host_culprit_stats[:percent] * 100).to_i
  emailresults(vm_culprit.name.downcase, host_culprit.name, host_culprit_stats[:type], host_culprit_percent, target_host.name)

  # Log the culprit VM
  $evm.log("info", "Migrating VM: <#{vm_culprit.name}> from Source Host: <#{host_culprit.name}> to Target Host: <#{target_host.name}>")

  # VMotion culprit VM to Target_host
  vm_culprit.migrate(target_host)
end
