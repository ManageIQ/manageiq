class MiqHostProvision < MiqRequestTask
  include_concern 'Configuration'
  include_concern 'PostInstallCallback'
  include_concern 'Ipmi'
  include_concern 'OptionsHelper'
  include_concern 'Placement'
  include_concern 'Pxe'
  include_concern 'Rediscovery'
  include_concern 'StateMachine'
  include_concern 'Tagging'

  alias_attribute :provision_type,             :request_type
  alias_attribute :miq_host_provision_request, :miq_request
  alias_attribute :host,                       :source

  include ReportableMixin

  validates_inclusion_of :request_type, :in => %w{ host_pxe_install },                           :message => "should be 'host_pxe_install'"
  validates_inclusion_of :state,        :in => %w{ pending queued active provisioned finished }, :message => "should be pending, queued, active, provisioned or finished"

  virtual_column :provision_type, :type => :string

  AUTOMATE_DRIVES   = true

  def self.get_description(prov_obj)
    prov_obj.description
  end

  def self.base_model
    MiqHostProvision
  end

  def deliver_to_automate
    super("host_provision")
  end

  def do_request
    signal :create_destination
  end

  def host_name
    self.host.name
  end
end
