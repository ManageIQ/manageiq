$:.push(File.expand_path(File.join(Rails.root, %w{.. lib Scvmm})))
require 'MiqScvmm'
#require 'MiqScvmmBroker'

class HostMicrosoft < Host
  def verify_credentials(auth_type = nil, _options = {})
    raise "no credentials defined" if missing_credentials?(auth_type)

    if MiqServer.my_server(true).has_role?(authentication_check_role)
      verify_credentials_windows(hostname, *auth_user_pwd(auth_type))
    else
      # Initiate a verify call from another EVM server if possible.
      verify_credentials_task(hostname, *auth_user_pwd(auth_type))
    end
  end

  def verify_credentials_task(*authentication)
    svr_list = MiqServer.all.select { |s| s.has_role?(authentication_check_role) }
    raise "No #{Dictionary::gettext("miq_servers", :type => :table)} were found to verify Windows credentials." if svr_list.blank?
    svr_list.delete_if {|s| s.status != 'started'}
    raise "No active #{Dictionary::gettext("miq_servers", :type => :table)} were found to verify Windows credentials." if svr_list.blank?

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
      _log.info "Connecting to WMI to verify credentials: [#{authentication[0]}] -[#{authentication[1]}]"
      WMIHelper.verify_credentials(*authentication)
    rescue Exception
      _log.warn("#{$!.inspect}")
      raise "Unexpected response returned from #{ui_lookup(:table => "ext_management_systems")}, see log for details"
    else
      true
    end
  end
end
