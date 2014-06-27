###################################
#
# EVM Automate Method: VM_Placement_Optimization
#
# Notes: When a VM encounters high CPU % Ready, VMotion VM to a more
# suitable host.
#
###################################
begin
  @method = 'VM_Placement_Optimization'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  def emailresults(vmname, target_host, vm_host, vmotion, event_type)
    # Get to_email_address from model unless specified below
    to = nil
    to ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']
    subject = "Alert! EVM has detected event [#{event_type}] on VM #{vmname}"

    body  = "Hello, "
    body += "<br>"
    body += "EVM has detected event: #{event_type} on VM: <b>#{vmname}</b> running on Host: <b>#{vm_host}</b>."
    body += "<br><br>"

    if vmotion
      body += "VM: <b>#{vmname}</b> will be moved to Host: <b>#{target_host}</b>"
    else
      body += "Host: <b>#{vm_host}</b> is already the lowest CPU % Ready Host. <br><br>"
      body += "VM: <b>#{vmname}</b> will NOT be moved."
    end

    body += "<br><br>"
    body += "Thank You,"
    body += "<br><br>"
    body += "#{signature}"
    body += "<br>"

    #
    # Send email
    #
    $evm.log("info", "#{@method} - Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
    $evm.execute('send_email', to, from, subject, body)
  end

  #
  # Initialize variables
  #
  vm = $evm.root['vm']
  raise "#{@method} - VM object not found" if vm.nil?
  # $evm.log("info","Inspecting vm object: <#{vm.inspect}>")

  vm_host = vm.host
  curr_host_cpu_percent = vm_host.get_realtime_metric(:v_pct_cpu_ready_delta_summation, [15.minutes.ago.utc, 5.minutes.ago.utc], :avg)

  process = $evm.object('process')
  event_type = process.attributes['event_type']
  event_type ||= 'High CPU Percent Ready Time'

  # Get the ESX Host scope from VC or Cluster
  # Default is to get ESX Hosts from the Cluster source VM resides
  host_scope = nil
  host_scope ||= $evm.object['host_scope']

  if host_scope && host_scope.downcase == "vc"
    ems = vm.ext_management_system
  else
    ems = vm.ems_cluster
  end
  $evm.log("info", "#{@method} - Detected Host Scope: <#{host_scope}>") if @debug
  $evm.log("info", "#{@method} - VM: <#{vm.name}> currently residing on Host: <#{vm_host.name}> with CPU % Ready: <#{curr_host_cpu_percent}>") if @debug

  # Get hosts attached to the VC
  hosts = ems.hosts

  # Loop through all hosts
  host_suspects = hosts.select { |h| h.power_state == 'on' && h.name != vm_host.name }

  host_all = []

  host_suspects.each do |h|
    host_cpu_percent = h.get_realtime_metric(:v_pct_cpu_ready_delta_summation, [15.minutes.ago.utc, 5.minutes.ago.utc], :avg)

    host_all << {:id => h.id, :percent => host_cpu_percent, :type => :cpu}
    $evm.log("info", "#{@method} - ESX Host: <#{h.name}> CPU Ready Delta Summation: <#{host_cpu_percent}>") if @debug
  end

  host_all.sort! { |a, b| a[:percent] <=> b[:percent] }

  target_host = host_suspects.detect { |h| h.id == host_all.first[:id] }
  vmotion = true
  if curr_host_cpu_percent <= host_all.first[:percent]
    $evm.log("info", "#{@method} - ESX Host: >#{target_host}> is the lowest CPU Ready Host. VM: <#{vm.name}> will NOT be moved.") if @debug
    vmotion = true
  else
    $evm.log("info", "#{@method} - VM: <#{vm.name}> will be moved to ESX Host: <#{target_host.name}> with CPU % Ready: <#{host_all.first[:percent]}>") if @debug
  end

  # Email Results
  emailresults(vm.name, target_host.name, vm_host, vmotion, event_type)

  # VMotion VM to Target_host
  if vmotion
    vm.migrate(target_host)
  end

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
