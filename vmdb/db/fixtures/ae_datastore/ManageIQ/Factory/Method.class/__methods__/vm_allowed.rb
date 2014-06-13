###################################
#
# EVM Automate Method: vm_allowed
#
# Notes: This method will parse a text file for vm names
#
###################################
begin
  @method = 'vm_allowed'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  obj = $evm.object("process")
  name = obj['vm_name']
  $evm.log("info", "VM Name: #{name}")

  exit MIQ_STOP unless %w(vm1 vm2 vm3).include?(name.downcase)

  fname = "/var/www/miq/vmdb/authorizedvms.txt"
  raise "File '#{fname}' does not exist" unless File.exist?(fname)

  allowed_names = File.read(fname).split("\n").collect { |n| n.downcase }
  $evm.log("info", "VM Allowed for #{obj['name']} Name: #{name} Allowed: #{allowed_names.inspect}") if @debug

  #
  # Look in the current object for a VM
  #
  vm = $evm.object['vm']
  if vm.nil?
    vm_id = $evm.object['vm_id'].to_i
    vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
  end

  #
  # Look in the Root Object for a VM
  #
  if vm.nil?
    vm = $evm.root['vm']
    if vm.nil?
      vm_id = $evm.root['vm_id'].to_i
      vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
    end
  end

  #
  # No VM Found, exit
  #
  if vm.nil?
    $evm.log("error", "Could not find VM in current or root objects")
    exit MIQ_ABORT
  end

  unless allowed_names.include?(name.downcase)
    $evm.log("info", "Unregistering VM: [#{name}]")
    vm.unregister

    # Tag the VM
    tag = "function/VM_REJECTED_BY_POLICY"
    vm.tag_assign(tag)
  else
    $evm.log("info", "Analyzing VM: [#{name}]")

    parent = $evm.object("..")
    profiles = parent.attributes["profiles"]
    $evm.log("info", "scan profiles: #{profiles.inspect}") if @debug

    job = vm.scan(profiles)
    $evm.log("info", "Job Attributes")
    job.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") unless k == 'process' }
  end

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
