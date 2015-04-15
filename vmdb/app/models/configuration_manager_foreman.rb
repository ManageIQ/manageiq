class ConfigurationManagerForeman < ConfigurationManager
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    "foreman_configuration".freeze
  end

  def self.process_tasks(options)
    raise "No ids given to process_tasks" if options[:ids].blank?
    if options[:task] == "refresh_ems"
      refresh_ems(options[:ids])
      create_audit_event(options)
    else
      options[:userid] ||= "system"
      unknown_task_exception(options)
      invoke_tasks_queue(options)
    end
  end

  def self.create_audit_event(options)
    msg = "'#{options[:task]}' initiated for #{options[:ids].length} #{ui_lookup(:table => 'ext_management_systems').pluralize}"
    AuditEvent.success(:event        => options[:task],
                       :target_class => base_class.name,
                       :userid       => options[:userid],
                       :message      => msg)
  end

  def self.unknown_task_exception(options)
    raise "Unknown task, #{options[:task]}" unless instance_methods.collect(&:to_s).include?(options[:task])
  end
end
