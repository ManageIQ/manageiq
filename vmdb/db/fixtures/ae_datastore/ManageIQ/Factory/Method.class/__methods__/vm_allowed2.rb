###################################
#
# EVM Automate Method: vm_allowed2
#
# Notes: This method will parse .csv file for vmnames
#
###################################
begin
  @method = 'vm_allowed2'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  def find_vm_in_csv(contents, name)
    contents.each do |line|
      CSV::Reader.parse(line) do |row|
        return line if row[0].downcase == name.downcase
      end
    end
    nil
  end

  def vm_allowed?(contents, name)
    find_vm_in_csv(contents, name).nil? ? false : true
  end

  def vm_tags(contents, name)
    line = find_vm_in_csv(contents, name)
    tags = []

    unless line.nil?
      CSV::Reader.parse(line) do |row|
        row.shift   # remove the name

        loop do
          tag = row.shift
          break if tag.nil?
          tags << tag
        end
      end
    end

    tags
  end

  obj = $evm.object("process")
  name = obj['vm_name']
  $evm.log("info", "VM Name: #{name}")

  exit MIQ_STOP unless %w(vm1 vm2 vm3).include?(name.downcase)

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

  require 'csv'
  fname = "/var/www/miq/vmdb/authorizedvms.csv"
  raise "File '#{fname}' does not exist" unless File.exist?(fname)

  csv = File.read(fname).split("\n")
  $evm.log("info", "VM Allowed for #{obj['name']} Name: #{name} CSV Contents: #{csv.inspect}") if @debug

  unless vm_allowed?(csv, name)
    $evm.log("info", "Unregistering VM: [#{name}]")
    vm.unregister

    # Tag the VM
    tag = "function/VM_REJECTED_BY_POLICY"
    vm.tag_assign(tag)
  else
    $evm.log("info", "Analyzing VM: [#{name}]")

    vm_tags(csv, name).each do |tag|
      $evm.log("info", "Tagging VM with [#{tag}]")
      vm.tag_assign(tag)
    end

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
  exit MIQ_ABORT
end
