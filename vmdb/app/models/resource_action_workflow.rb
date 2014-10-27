class ResourceActionWorkflow < MiqRequestWorkflow
  attr_accessor :dialog

  def self.base_model
    ResourceActionWorkflow
  end

  def initialize(values, requester, resource_action, options={})
    @settings        = {}
    @requester       = @owner    = MiqLdap.using_ldap? ? User.find_or_create_by_ldap_upn(requester) : User.find_by_userid(requester)
    @requester_id    = @owner_id = @requester.userid
    @target          = options[:target]
    @dialog          = load_dialog(resource_action, values)

    @settings[:resource_action_id] = resource_action.id unless resource_action.nil?
    @settings[:dialog_id]          = @dialog.id         unless @dialog.nil?
  end

  def dialogs
    msg = "[DEPRECATION] ResourceActionWorkflow#dialogs should not be used.  Please use ResourceActionWorkflow#dialog instead.  At #{caller[0]}"
    $log.warn msg
    Kernel.warn msg
    dialog
  end

  def submit_request(requester_id, auto_approve=false)
    result = {}

    result[:errors] = @dialog.validate
    return result unless result[:errors].blank?

    values = create_values_hash
    values[:src_id] = @target.id

    if create_request?(values)
      event_message = "Request by [#{requester_id}] for #{@target.class.name}:#{@target.id}"
      result[:request] = create_request(values, requester_id, @target.class.name,
                                        'resource_action_request_created', event_message, auto_approve)
    else
      ra = load_resource_action(values)
      ra.deliver_to_automate_from_dialog(values, @target)
    end
    result
  end

  def request_class
    @target.request_class
  end

  def has_request_class?
    !self.request_class.nil? rescue false
  end

  def request_type
    @target.request_type
  end

  def load_resource_action(values=nil)
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

  def load_dialog(resource_action, values)
    if resource_action.nil?
      resource_action = load_resource_action(values)
      @settings[:resource_action_id] = resource_action.id unless resource_action.nil?
    end

    dialog = resource_action.dialog unless resource_action.nil?
    unless dialog.nil?
      dialog.target_resource = @target
      dialog.init_fields_with_values(values)
    end
    dialog
  end

  def init_field_hash
    result = {}
    @dialog.each_dialog_field { |df| result[df.name] = df }
    result
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

  def validate(values=nil)
    @dialog.try(:validate)
  end

  private

  def create_request?(values)
    ra = load_resource_action(values)
    !ra.resource.kind_of?(CustomButton) && has_request_class?
  end
end
