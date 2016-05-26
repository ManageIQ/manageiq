class OrchestrationTemplateVnfd < OrchestrationTemplate
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"

  before_create :raw_create, :if => :remote_proxy?
  before_update :raw_update, :if => :remote_proxy?
  before_destroy :raw_destroy, :if => :remote_proxy?

  def raw_create
    vnfd_data = {:attributes    => {:vnfd => content},
                 :service_types => [{:service_type => "vnfd"}],
                 :mgmt_driver   => "noop",
                 :infra_driver  => "heat"}

    vnfd_data[:name] = name unless name.blank?
    vnfd_data[:description] = description unless description.blank?

    connection_options = {:service => "NFV"}
    ext_management_system.with_provider_connection(connection_options) do |service|
      self.ems_ref = service.vnfds.create(:vnfd => vnfd_data, :auth => {}).id
    end
  end

  def raw_update
    # Tacker does not have an update call
    raw_destroy && raw_create
  end

  def raw_destroy
    connection_options = {:service => "NFV"}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.vnfds.get(ems_ref).try(:destroy)
    end
  end

  def parameter_groups
    []
  end

  def parameters
    []
  end

  def self.eligible_manager_types
    [ManageIQ::Providers::Openstack::CloudManager]
  end

  # return the parsing error message if not valid YAML; otherwise nil
  def validate_format
    YAML.parse(content) && nil if content
  rescue Psych::SyntaxError => err
    err.message
  end

  def unique_md5?
    false
  end

  def save_as_orderable!
    error_msg = validate_format unless draft
    raise MiqException::MiqParsingError, error_msg if error_msg

    self.orderable = true
    save!
  end
end
