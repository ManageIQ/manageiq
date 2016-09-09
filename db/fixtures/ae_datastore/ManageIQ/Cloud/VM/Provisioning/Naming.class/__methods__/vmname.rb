# / Cloud / VM / Provisioning / Naming / default (vmname)

#
# Description: This is the default naming scheme
# 1. If VM Name was not chosen during dialog processing then use vm_prefix
#    from dialog else use model and [:environment] tag to generate name
# 2. Else use VM name chosen in dialog
# 3. Add 3 digit suffix to vmname if more than one VM is being provisioned
#

class VmName
  def initialize(handle = $evm)
    @handle = handle
  end

  def main
    @handle.log("info", "Detected vmdb_object_type:<#{@handle.root['vmdb_object_type']}>")
    @handle.object['vmname'] = derived_name.compact.join
    @handle.log(:info, "vmname: \"#{@handle.object['vmname']}\"")
  end

  def derived_name
    if supplied_name.present?
      [supplied_name, suffix(true)]
    else
      [prefix, env_tag, suffix(false)]
    end
  end

  def supplied_name
    @supplied_name ||= begin
      vm_name = provision_object.get_option(:vm_name).to_s.strip
      vm_name unless vm_name == 'changeme'
    end
  end

  def provision_object
    @provision_object ||= begin
      @handle.root['miq_provision_request'] ||
      @handle.root['miq_provision']         ||
      @handle.root['miq_provision_request_template']
    end
  end

  # Returns the name prefix (preferences model over dialog) or nil
  def prefix
    @handle.object['vm_prefix'] || provision_object.get_option(:vm_prefix).to_s.strip
  end

  # Returns the first 3 characters of the "environment" tag (or nil)
  def env_tag
    env = provision_object.get_tags[:environment]
    return env[0, 3] unless env.blank?
  end

  # Returns the name suffix (provision number) or nil if provisioning only one
  def suffix(condensed)
    "$n{3}" if provision_object.get_option(:number_of_vms) > 1 || !condensed
  end
end

if __FILE__ == $PROGRAM_NAME
  VmName.new.main
end
