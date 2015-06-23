class MiqProvisionWorkflow < MiqRequestWorkflow
  def self.base_model
    MiqProvisionWorkflow
  end

  def self.class_for_platform(platform)
    "MiqProvision#{platform.titleize}Workflow".constantize
  end

  def self.class_for_source(source_or_id)
    source = source_or_id.kind_of?(ActiveRecord) ? source_or_id : VmOrTemplate.find_by_id(source_or_id)
    return nil if source.nil?
    class_for_platform(source.class.model_suffix)
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

  def supports_customization_template?
    supports_pxe? || supports_iso? || supports_cloud_init?
  end

  def continue_request(values, _requester_id)
    return false unless validate(values)

    exit_pre_dialog if @running_pre_dialog
    password_helper(@values, false) # Decrypt passwords in the hash for the UI
    @dialogs    = get_dialogs
    @last_vm_id = get_value(@values[:src_vm_id])
    @tags       = nil  # Force tags to reload
    set_default_values

    true
  end

  def update_request(request, values, requester_id, target_class, event_name, event_message)
    request = request.kind_of?(MiqRequest) ? request : MiqRequest.find(request)
    request.src_vm_id = request.get_option(:src_vm_id)
    super
  end
end
