require 'MiqVim'
require 'dbi'
require 'miq-process'

VC_IP, VC_USER, VC_PASS, LOG_DIR = ARGV

VC_ACCESSORS = [
  [:dataStoresByMor, :storage],
  [:hostSystemsByMor, :host],
  [:virtualMachinesByMor, :vm],
  [:datacentersByMor, :dc],
  [:foldersByMor, :folder],
  [:clusterComputeResourcesByMor, :cluster],
  [:computeResourcesByMor, :host_res],
  [:resourcePoolsByMor, :rp],
]

LOG_DIR ||= "./"
logfile = File.join(LOG_DIR, "env_probe_vc_inv.log")
File.delete(logfile) if File.exist?(logfile)
$log = VMDBLogger.new(logfile)
$log.level = VMDBLogger.const_get("DEBUG")

inv_yml = File.join(LOG_DIR, "env_probe_vc_inv.yml")
File.delete(inv_yml) if File.exist?(inv_yml)
$yml_fd = File.open(inv_yml, "w")

require 'MiqVim'
require 'dbi'

def log(level, msg)
  puts "[#{Time.now.utc}] #{level.to_s.upcase}: #{msg}"
  $log.send(level, msg)
end

def vim_vc_connect
  log :info, "Connecting to EMS: [#{VC_IP}], as [#{VC_USER}]..."
  @vc_data = {}
  @vi = nil
  @vi = MiqVim.new(VC_IP, VC_USER, VC_PASS)
  log :info, "Connecting to EMS: [#{VC_IP}], as [#{VC_USER}]... Complete"
end

def vim_vc_inv_hash
  @vi.inventoryHash
end

### Main

# verify we are in the vmdb directory
unless File.exist?('app')
  log :error, "Please run this script using 'script/runner perf_environment.rb' from vmdb directory"
  exit 1
end

log :info, "Running EMS Inventory tests..."

log :info, "EMS Host: #{VC_IP}"
log :info, "EMS User: #{VC_USER}"

log :info, "Process stats: #{MiqProcess.processInfo.inspect}"

begin
  t0 = Time.now
  vc_data = {}
  con = vim_vc_connect
  inv = vim_vc_inv_hash
  log :info, "Requesting inventory accessors..."
  VC_ACCESSORS.each do |acc, type|
    inv_hash = @vi.send(acc)
    vc_data[type] = inv_hash
  end
rescue => err
  log :error, err
  exit 1
end

log :info, "Running EMS Inventory tests... Complete, Elapsed time: [#{Time.now.to_i - t0.to_i} seconds]"
log :info, "EMS Inventory summary: " + vc_data.collect {|k,v| k.to_s << "=>" << v.length.to_s}.inspect
log :info, "Process stats: #{MiqProcess.processInfo.inspect}"

log :info, "Writing inventory to #{inv_yml}..."
$yml_fd.write(YAML.dump(vc_data))
$yml_fd.close

log :info, "Done"

exit 0
