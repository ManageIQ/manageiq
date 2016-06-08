class CloudService < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :host
  belongs_to :system_service
  belongs_to :availability_zone

  alias_attribute :name, :executable_name

  def fog_service
    connection_options = {:service => source}
    ext_management_system.with_provider_connection(connection_options) do |service|
      # TODO(pblaho): remove find and used get when https://github.com/fog/fog-openstack/pull/88 is released
      service.services.find { |s| s.id.to_s == ems_ref }
    end
  end

  def enable_scheduling
    fog_service.enable
  end

  def disable_scheduling
    fog_service.disable
  end

  def validate_enable_scheduling
    fog_service && scheduling_disabled?
  end

  def validate_disable_scheduling
    fog_service && scheduling_enabled?
  end

  def scheduling_enabled?
    !scheduling_disabled?
  end

  def delete_service
    connection_options = {:service => source}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.delete_service(ems_ref)
    end
  end
end
