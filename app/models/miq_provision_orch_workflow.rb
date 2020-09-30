class MiqProvisionOrchWorkflow < MiqProvisionVirtWorkflow
  def initialize(values, requester, options = {})
    initial_pass = values.blank?
    initial_pass = true if options[:initial_pass] == true
    instance_var_init(values, requester, options)

    # Check if the caller passed the source VM as part of the initial call
    if initial_pass == true
      src_obj_id = get_value(@values[:src_vm_id])
      unless src_obj_id.blank?
        src_obj = OrchestrationTemplate.find_by(:id => src_obj_id)
        @values[:src_vm_id] = [src_obj.id, src_obj.name] unless src_obj.blank?
      end
    end

    unless options[:skip_dialog_load] == true
      # If this is the first time we are called the values hash will be empty
      # Also skip if we are being called from a web-service
      @dialogs = get_pre_dialogs if initial_pass && options[:use_pre_dialog] != false
      if @dialogs.nil?
        @dialogs = get_dialogs
      else
        @running_pre_dialog = true if options[:use_pre_dialog] != false
      end
      normalize_numeric_fields unless @dialogs.nil?
    end

    password_helper(@values, false) # Decrypt passwords in the hash for the UI
    @last_vm_id = get_value(@values[:src_vm_id]) unless initial_pass == true

    return if options[:skip_dialog_load] == true

    set_default_values
    update_field_visibility

    if get_value(values[:service_template_request])
      show_dialog(:requester, :hide, "disabled")
      show_dialog(:purpose,   :hide, "disabled")
    end
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false

    vm_id = get_value(@values[:src_vm_id])
    rails_logger('get_source_and_targets', 0)
    svm = OrchestrationTemplate.find_by(:id => vm_id)

    return @target_resource = {} if svm.nil?

    result = {}
    result[:vm] = ci_to_hash_struct(svm)
    result[:ems] = ci_to_hash_struct(svm.ext_management_system)

    result
  end

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, filtered_ids = nil)
    return {} if get_value(@values[:placement_auto]) == true
    return {} if (sources = resources_for_ui).blank?
    get_ems_metadata_tree(sources)
    super(ci, relats, sources, filtered_ids)
  end
end
