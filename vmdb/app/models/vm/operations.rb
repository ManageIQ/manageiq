module Vm::Operations
  include_concern 'Guest'
  include_concern 'Power'

  def validate_collect_running_processes
    s = {:available=>false, :message=> nil}

    # Report reasons why collection is not available for this VM
    unless ['windows'].include?(self.platform)
      s[:message] = 'VM Process collection is only available for Windows VMs.'
      return s
    end
    unless self.runnable?
      s[:message] = 'VM Process collection is only available for Runnable VMs.'
      return s
    end

    # From here on out collection is possible, but may not be currently available.
    s[:available] = true
    unless self.state == "on"
      s[:message] = 'VM Process collection is only available while the VM is powered on.'
      return s
    end

    if self.my_zone.nil? || self.my_zone_obj.auth_user_pwd(:windows_domain).nil?
      s[:message] = 'VM Process collection requires credentials set at the Zone level.'
      return s
    end

    if self.ipaddresses.blank?
      s[:message] = 'VM Process collection requires an IP address for the VM.'
      return s
    end

    return s
  end

  private

  def validate_unsupported(message_prefix)
    { :available => false, :message => "#{message_prefix} is not available for #{self.class.model_suffix} VM." }
  end


end
