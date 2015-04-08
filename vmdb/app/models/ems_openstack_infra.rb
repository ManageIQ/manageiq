class EmsOpenstackInfra < EmsInfra
  include EmsOpenstackMixin

  before_save :ensure_parent_provider

  has_many :orchestration_stacks, :foreign_key => :ems_id, :dependent => :destroy

  def ensure_parent_provider
    # TODO(lsmola) this might move to a general management of Providers, but for now, we will ensure, every
    # EmsOpenstackInfra has associated a Provider. This relation will serve for relating EmsOpenstackInfra
    # to possible many EmsOpenstacks deployed through EmsOpenstackInfra

    # Name of the provider needs to be unique, get provider if there is one like that
    self.provider = ProviderOpenstack.find_by_name(name) unless self.provider

    attributes = {:name => name, :zone => zone}
    if self.provider
      self.provider.update_attributes!(attributes)
    else
      self.provider = ProviderOpenstack.create!(attributes)
    end
  end

  def self.ems_type
    @ems_type ||= "openstack_infra".freeze
  end

  def self.description
    @description ||= "OpenStack Infrastructure".freeze
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default amqp keypair)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.event_monitor_class
    MiqEventCatcherOpenstackInfra
  end
end
