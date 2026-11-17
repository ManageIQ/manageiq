class MiqProvisionConfigurationScriptRequest < MiqRequest
  delegate :my_zone, :to => :source

  TASK_DESCRIPTION  = N_('Automation Provider Provisioning')
  SOURCE_CLASS_NAME = 'ConfigurationScript'

  default_value_for(:source_id)   { |r| r.get_option(:src_configuration_script_id) }
  default_value_for :source_type, "ConfigurationScript"
  validates :source, :presence => true
  validate  :must_have_user

  def self.request_task_class_from(attribs)
    source_id = MiqRequestMixin.get_option(:src_configuration_script_id, nil, attribs['options'])
    configuration_script = source_configuration_script!(source_id)
    configuration_script.manager.class.provision_class(nil)
  end

  def self.source_configuration_script!(source_id)
    configuration_script = ::ConfigurationScript.find_by(:id => source_id)
    raise MiqException::MiqProvisionError, "Unable to find source ConfigurationScript with id [#{source_id}]"                  if configuration_script.nil?
    raise MiqException::MiqProvisionError, "Source ConfigurationScript with id [#{source_id}] has no EMS, unable to provision" if configuration_script.manager.nil?

    configuration_script
  end

  def self.new_request_task(attribs)
    request_task_class_from(attribs).new(attribs)
  end

  def customize_request_task_attributes(_req_task_attrs, _idx)
  end

  def requested_task_idx
    [-1] # we are only using one task per request
  end

  def originating_controller
    "configuration_scripts"
  end

  def event_name(mode)
    "configuration_script_provision_request_#{mode}"
  end
end
