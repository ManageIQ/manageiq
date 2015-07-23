module ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask::OptionsHelper
  def log_provider_options
    _log.info("Provisioning [#{source.name}]")
  end

  def merge_provider_options_from_automate
    phase_context[:provider_options].merge!(get_option(:provider_options) || {})
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Merged Provider Options: ", $log, :info, :protected => {:path => /root_pass/})
  end

  def prepare_provider_options
    h = {"hostgroup_id" => dest_configuration_profile.manager_ref, "medium_id" => nil, "operatingsystem_id" => nil, "ptable_id" => nil}
    h["name"]      = options[:hostname]                           if options[:hostname]
    h["ip"]        = options[:ip_addr]                            if options[:ip_addr]
    h["root_pass"] = MiqPassword.decrypt(options[:root_password]) if options[:root_password]
    phase_context[:provider_options] = h
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Default Provider Options: ", $log, :info, :protected => {:path => /root_pass/})
  end

  def validate_source
    raise MiqException::MiqProvisionError, "Unable to find #{model_class} with id #{source_id.inspect}" if source.blank?
  end

  def dest_configuration_profile
    @dest_configuration_profile ||= ::ConfigurationProfile.where(:id => get_option(:src_configuration_profile_id)).first
  end
end
