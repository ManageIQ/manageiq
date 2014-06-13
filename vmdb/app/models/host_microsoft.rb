$:.push(File.expand_path(File.join(Rails.root, %w{.. lib Scvmm})))
require 'MiqScvmm'
#require 'MiqScvmmBroker'

class HostMicrosoft < Host
  def verify_credentials(auth_type=nil, options={})
    raise "no credentials defined" if self.authentication_invalid?(auth_type)

    return verify_credentials_windows(self.ipaddress, *self.auth_user_pwd(auth_type)) if MiqServer.my_server(true).has_role?(authentication_check_role)

    # Initiate a verify call from another EVM server if possible.
    return verify_credentials_task(self.ipaddress, *self.auth_user_pwd(auth_type))
  end

  def verify_credentials_task(*authentication)
    svr_list = MiqServer.find(:all).collect {|s| s.has_role?(authentication_check_role) ? s : nil}.compact
    raise "No #{Dictionary::gettext("miq_servers", :type=>:table)} were found to verify Windows credentials." if svr_list.blank?
    svr_list.delete_if {|s| s.status != 'started'}
    raise "No active #{Dictionary::gettext("miq_servers", :type=>:table)} were found to verify Windows credentials." if svr_list.blank?

    options = { :action => "Host(Windows) - Validate credentials", :userid => 'system'}
    queue_options = {:class_name => self.class.name,
                     :method_name => 'verify_credentials_windows',
                     :args => authentication,
                     :instance_id => self.id,
                     :priority => MiqQueue::HIGH_PRIORITY,
                     :role => authentication_check_role,
                     :msg_timeout => 60
                     }

    task = MiqTask.wait_for_taskid(MiqTask.generic_action_with_callback(options, queue_options))
    return task.task_results if task.status == "Ok"
    raise task.message
  end

  def verify_credentials_windows(*authentication)
    begin
      require 'miq-wmi'
      $log.info "MIQ(Host-Microsoft-verify_credentials): Connecting to WMI to verify credentials: [#{authentication[0]}] -[#{authentication[1]}]"
      WMIHelper.verify_credentials(*authentication)
    rescue Exception
      $log.warn("MIQ(Host-Microsoft-verify_credentials): #{$!.inspect}")
      raise "Unexpected response returned from #{ui_lookup(:table=>"ext_management_systems")}, see log for details"
    else
      true
    end
  end
end
