class ResourceActionWorkflow < MiqRequestWorkflow
  attr_accessor :dialog

  def self.base_model
    ResourceActionWorkflow
  end

  def initialize(values, requester, resource_action, options = {})
    @settings        = {}
    @requester       = requester
    @target          = options[:target]
    @dialog          = load_dialog(resource_action, values, options)

    @settings[:resource_action_id] = resource_action.id unless resource_action.nil?
    @settings[:dialog_id]          = @dialog.id         unless @dialog.nil?
  end

  def dialogs
    msg = "[DEPRECATION] ResourceActionWorkflow#dialogs should not be used.  Please use ResourceActionWorkflow#dialog instead.  At #{caller[0]}"
    $log.warn msg
    Kernel.warn msg
    dialog
  end

  def submit_request
    process_request(ServiceOrder::STATE_ORDERED)
  end

  def add_request_to_cart
    process_request(ServiceOrder::STATE_CART)
  end

  def process_request(state)
    result = {:errors => validate_dialog}
    return result unless result[:errors].blank?

    values = create_values
    if create_request?(values)
      result[:request] = generate_request(state, values)
    else
      ra = load_resource_action(values)
      ra.deliver_to_automate_from_dialog(values, @target, @requester)
    end

    result
  end

  def generate_request(state, values)
    make_request(nil, values.merge(:cart_state => state))
  end

  def validate_dialog
    @dialog.validate_field_data
  end

  def create_values
    create_values_hash.tap { |value| value[:src_id] = @target.id }
  end

  def request_class
    @target.request_class
  end

  def has_request_class?
    !request_class.nil? rescue false
  end

  def request_type
    @target.request_type
  end

  def load_resource_action(values = nil)
    if values.nil?
      ResourceAction.find_by_id(@settings[:resource_action_id])
    else
      ResourceAction.find_by_id(values.fetch_path(:workflow_settings, :resource_action_id))
    end
  end

  def create_values_hash
    {
      :dialog            => @dialog.automate_values_hash,
      :workflow_settings => @settings
    }
  end

  def load_dialog(resource_action, values, options)
    if resource_action.nil?
      resource_action = load_resource_action(values)
      @settings[:resource_action_id] = resource_action.id unless resource_action.nil?
    end

    dialog = resource_action.dialog unless resource_action.nil?
    unless dialog.nil?
      dialog.target_resource = @target
      if options[:display_view_only]
        dialog.init_fields_with_values_for_request(values)
      else
        dialog.init_fields_with_values(values)
      end
    end
    dialog
  end

  def init_field_hash
    @dialog.dialog_fields.each_with_object({}) { |df, result| result[df.name] = df }
  end

  def set_value(name, value)
    dlg_field = dialog_field(name)
    if dlg_field.nil?
      Rails.logger.warn("ResourceActionWorkflow.set_value dialog field with name <#{name.class.name}:#{name.inspect}> not found")
      return nil
    end

    dlg_field.value = value
    # TODO: Return list of changed field names
    nil
  end

  def value(name)
    dlg_field = @dialog.field(name)
    dlg_field.value if dlg_field
  end

  def dialog_field(name)
    @dialog.field(name)
  end

  def validate(_values = nil)
    validate_dialog.blank?
  end

  private

  def create_request?(values)
    ra = load_resource_action(values)
    !ra.resource.kind_of?(CustomButton) && has_request_class?
  end
end
