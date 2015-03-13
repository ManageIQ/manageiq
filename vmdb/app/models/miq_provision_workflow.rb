class MiqProvisionWorkflow < MiqRequestWorkflow
  SUBCLASSES = %w{
    MiqProvisionConfiguredSystemWorkflow
    MiqProvisionVirtWorkflow
  }

  def self.base_model
    MiqProvisionWorkflow
  end

  def self.all_encrypted_options_fields(klass = nil, encrypted_fields = {})
    klass ||= self
    return encrypted_fields[klass.name] if encrypted_fields.key?(klass.name)
    encrypted_fields[klass.name] = Array.wrap(
      klass.respond_to?(:encrypted_options_fields) ? klass.encrypted_options_fields : nil
    )
    if defined?(klass::SUBCLASSES)
      klass::SUBCLASSES.each do |c|
        encrypted_fields[klass.name] |= all_encrypted_options_fields(c.constantize, encrypted_fields)
      end
    end
    encrypted_fields[klass.name]
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
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionWorkflow::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
