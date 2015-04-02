require 'manageiq_foreman'
module MiqProvisionTaskConfiguredSystemForeman::OptionsHelper
  def log_provider_options
    $log.info("MIQ(#{self.class.name}##{__method__}) Provisioning [#{source.name}]")
  end

  def merge_provider_options_from_automate
    phase_context[:provider_options].merge!(get_option(:provider_options) || {}).delete_nils
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Merged Provider Options: ", $log, :info)
  end

  def prepare_provider_options
    h = {"hostgroup_id" => dest_configuration_profile.manager_ref}
    h["name"]      = options[:hostname]                           if options[:hostname]
    h["ip"]        = options[:ip_addr]                            if options[:ip_addr]
    h["root_pass"] = MiqPassword.decrypt(options[:root_password]) if options[:root_password]
    phase_context[:provider_options] = h
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Default Provider Options: ", $log, :info)
  end

  def validate_source
    raise MiqException::MiqProvisionError, "Unable to find #{model_class} with id #{source_id.inspect}" if source.blank?
  end

  def dest_configuration_profile
    @dest_configuration_profile ||= ConfigurationProfile.where(:id => get_option(:src_configuration_profile_id)).first
  end
end
