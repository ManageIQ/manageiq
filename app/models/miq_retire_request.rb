class MiqRetireRequest < MiqRequest
  validates :request_state, :inclusion => {:in => %w[pending finished] + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"}
  validate :must_have_user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }

  def my_zone
  end

  # Provider-specific task class support
  def self.request_task_class_from(attribs)
    source_id = MiqRequestMixin.get_option(:src_ids, nil, attribs["options"])
    source    = find_source!(source_id)

    # Check if source has EMS and supports provider-specific retire task class
    if source.respond_to?(:ext_management_system) && source.ext_management_system
      ems_retire_task_class(source) || default_retire_task_class
    else
      default_retire_task_class
    end
  end

  def self.new_request_task(attribs)
    klass = request_task_class_from(attribs)
    klass.new(attribs)
  end

  private_class_method def self.find_source!(source_id)
    source_class = self::SOURCE_CLASS_NAME.constantize
    source = source_class.find_by(:id => source_id)

    if source.nil?
      raise MiqException::MiqRetireRequestError,
            "Unable to find #{source_class.name} with id [#{source_id}]"
    end

    source
  end

  private_class_method def self.ems_retire_task_class(source)
    ems = source.ext_management_system
    return nil unless ems

    # Call the appropriate EMS method based on source type
    method_name = retire_task_class_method_name
    ems.class.respond_to?(method_name) ? ems.class.send(method_name) : nil
  end

  private_class_method def self.retire_task_class_method_name
    # Convert source class name to method name
    # Vm -> vm_retire_task_class
    # OrchestrationStack -> orchestration_stack_retire_task_class
    source_class_name = self::SOURCE_CLASS_NAME.underscore
    "#{source_class_name}_retire_task_class"
  end

  private_class_method def self.default_retire_task_class
    # Default to the request_task_class from MiqRequest
    request_task_class
  end
end
