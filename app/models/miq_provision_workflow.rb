class MiqProvisionWorkflow < MiqRequestWorkflow
  def self.base_model
    MiqProvisionWorkflow
  end

  # Find the appropriate workflow class for the given 'platform' string.
  #
  # @example openstack
  #   "ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow"
  #
  # @param platform [String]
  #   A string of the one of the ManageIQ providers. The case of this
  #   string is ignored.
  #
  # @return [Constant] A scoped provider constant name.
  #
  def self.class_for_platform(platform)
    classy = platform.classify

    find_matching_constant("MiqProvision#{classy}Workflow") ||
      find_matching_constant("ManageIQ::Providers::#{classy}::CloudManager::ProvisionWorkflow") ||
      find_matching_constant("ManageIQ::Providers::#{classy}::InfraManager::ProvisionWorkflow")
  end

  def self.find_matching_constant(string)
    const = string.safe_constantize
    const if const.try(:name) == string
  end
  private_class_method :find_matching_constant

  def self.class_for_source(source_or_id)
    source = case source_or_id
             when ActiveRecord::Base then source_or_id
             else VmOrTemplate.find_by(:id => source_or_id)
             end
    return nil if source.nil?
    source.class.manager_class.provision_workflow_class
  end

  def self.encrypted_options_fields
    [:root_password]
  end

  def self.request_class
    MiqProvisionRequest
  end

  def self.automate_dialog_request
    'UI_PROVISION_INFO'
  end

  def self.default_dialog_file
    'miq_provision_dialogs'
  end

  def supports_pxe?
    false
  end

  def supports_iso?
    false
  end

  def supports_cloud_init?
    false
  end

  def supports_sysprep?
    false
  end

  def supports_customization_template?
    supports_pxe? || supports_iso? || supports_cloud_init? || supports_sysprep?
  end

  def continue_request(values)
    return false unless validate(values)

    exit_pre_dialog if @running_pre_dialog
    password_helper(@values, false) # Decrypt passwords in the hash for the UI
    @dialogs    = get_dialogs
    @last_vm_id = get_value(@values[:src_vm_id])
    @tags       = nil  # Force tags to reload
    set_default_values

    true
  end
end
