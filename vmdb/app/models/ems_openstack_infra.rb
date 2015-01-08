class EmsOpenstackInfra < EmsInfra
  include EmsOpenstackMixin

  def self.ems_type
    @ems_type ||= "openstack_infra".freeze
  end

  def self.description
    @description ||= "OpenStack Infrastructure".freeze
  end
end
