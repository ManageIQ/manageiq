class EmsOpenstackInfra < EmsInfra
  include EmsOpenstackMixin

  has_many :orchestration_stacks, :foreign_key => :ems_id, :dependent => :destroy

  def self.ems_type
    @ems_type ||= "openstack_infra".freeze
  end

  def self.description
    @description ||= "OpenStack Infrastructure".freeze
  end

  def supports_port?
    true
  end

  def supports_authentication?(authtype)
    %w(default amqp).include?(authtype.to_s)
  end

  def self.event_monitor_class
    MiqEventCatcherOpenstackInfra
  end
end
