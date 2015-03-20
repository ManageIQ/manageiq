require 'manageiq_foreman'
module MiqProvisionTaskConfiguredSystemForeman::OptionsHelper
  def log_provider_options
    log_header = "MIQ(#{self.class.name}##{__method__})"
    $log.info("#{log_header} Provisioning [#{source.name}]")
  end

  def merge_provider_options_from_automate
    phase_context[:provider_options].merge!(get_option(:provider_options) || {}).delete_nils
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Merged Provider Options: ", $log, :info)
  end

  def prepare_provider_options
    phase_context[:provider_options] = {
      "id"           => source.manager_ref,
      "hostgroup_id" => dest_configuration_profile.manager_ref,
    }
    dumpObj(phase_context[:provider_options], "MIQ(#{self.class.name}##{__method__}) Default Provider Options: ", $log, :info)
  end

  def set_source_from_options
    source_id = get_option(:src_configured_system_id)
    source    = model_class.where(:id => source_id).first
    raise MiqException::MiqProvisionError, "Unable to find #{model_class} with id #{source_id.inspect}" if source.blank?
    update_attrubites(:source => source)
  end

  def dest_configuration_profile
    @dest_configuration_profile ||= ConfigurationProfile.where(:id => get_option(:src_configuration_profile_id)).first
  end
end
