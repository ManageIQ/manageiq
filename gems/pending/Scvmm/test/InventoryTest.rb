$:.push("#{File.dirname(__FILE__)}/..")
require 'MiqScvmmInventory'
require 'yaml'

out_file = "d:/temp/scvmm/scvmm_inv.dump"
out_file_yaml = File.join(File.dirname(out_file), File.basename(out_file, ".*") + ".yaml")

#@cache = true
if @cache
  x = MiqScvmmInventory.new('host', 'user', 'password')
  x.refresh() do |ems_data|
    File.open(out_file,"wb") {|f| Marshal.dump(ems_data, f)}
    File.open(out_file_yaml,"w") {|f| YAML.dump(ems_data, f)}
  end
  x.disconnect
else
  ems_data = nil; File.open(out_file,"rb") {|f| ems_data = Marshal.load(f)}
  vmdb_hash = MiqScvmmInventory.to_inv_h(ems_data)
  vmdb_hash
  File.open("d:/temp/scvmm/scvmm_ems_hash.yaml","w") {|f| YAML.dump(vmdb_hash, f)}
end

puts 'done'
