class ResourceActionWorkflow < MiqRequestWorkflow
  attr_accessor :dialog
  attr_accessor :request_options

  attr_reader :target

  def self.base_model
    ResourceActionWorkflow
  end

  def initialize(values, requester, resource_action, options = {})
    @settings        = {}
    @requester       = requester
    @target          = options[:target]
    @initiator       = options[:initiator]
    @dialog          = load_dialog(resource_action, values, options)

    @settings[:resource_action_id] = resource_action.id if resource_action
    @settings[:dialog_id]          = @dialog.id         if @dialog
  end

  Vmdb::Deprecation.deprecate_methods(self, :dialogs => :dialog)

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
    @dialog.try(:validate_field_data) || []
  end

  def create_values
    create_values_hash.tap do |value|
      value[:src_id] = @target.id
      value[:request_options] = request_options unless request_options.blank?
    end
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
    id = values ? values.fetch_path(:workflow_settings, :resource_action_id) : @settings[:resource_action_id]
    ResourceAction.find_by(:id => id)
  end

  def create_values_hash
    {
      :dialog            => @dialog.try(:automate_values_hash),
      :workflow_settings => @settings,
      :initiator         => @initiator
    }
  end

  def load_dialog(resource_action, values, options)
    if resource_action.nil?
      resource_action = load_resource_action(values)
      @settings[:resource_action_id] = resource_action.id if resource_action
    end

    dialog = resource_action.dialog if resource_action
    if dialog
      dialog.target_resource = @target
      if options[:display_view_only]
        dialog.init_fields_with_values_for_request(values)
      elsif options[:provision_workflow]
        dialog.initialize_value_context(values)
        dialog.load_values_into_fields(values, false)
      elsif options[:refresh] || options[:submit_workflow]
        dialog.load_values_into_fields(values)
      elsif options[:reconfigure]
        dialog.initialize_with_given_values(values)
      else
        dialog.initialize_value_context(values)
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
    @dialog.field(name)&.value
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
