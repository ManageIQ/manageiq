# / Cloud / VM / Provisioning / Naming / default (vmname)

#
# Description: This is the default naming scheme
# 1. If VM Name was not chosen during dialog processing then use vm_prefix
#    from dialog else use model and [:environment] tag to generate name
# 2. Else use VM name chosen in dialog
# 3. Add 3 digit suffix to vmname if more than one VM is being provisioned
#

# Returns the name prefix (preferences model over dialog) or nil
def get_prefix(prov)
  $evm.object['vm_prefix'] || prov.get_option(:vm_prefix).to_s.strip
end

# Returns the first 3 characters of the "environment" tag (or nil)
def get_env_tag(prov)
  env = prov.get_tags[:environment]
  return env[0, 3] unless env.blank?
end

# Returns the name suffix (provision number) or nil if provisioning only one
def get_suffix(prov, condensed)
  "$n{3}" if prov.get_option(:number_of_vms) > 1 || !condensed
end

$evm.log("info", "Detected vmdb_object_type:<#{$evm.root['vmdb_object_type']}>")
prov = $evm.root['miq_provision_request'] || $evm.root['miq_provision'] || $evm.root['miq_provision_request_template']
vm_name = prov.get_option(:vm_name).to_s.strip
vm_name = vm_name == 'changeme' ? nil : vm_name

# If the name is already specified, use it and exit
if !vm_name.blank?
  derived_name = [vm_name, get_suffix(prov, true)]
else
  derived_name = [get_prefix(prov), get_env_tag(prov), get_suffix(prov, false)]
end

$evm.object['vmname'] = derived_name.compact.join("_")
$evm.log(:info, "vmname: \"#{$evm.object['vmname']}\"")
