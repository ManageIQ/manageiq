class NamespaceEmsOpenstackAvailabilityZonesNull < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    AvailabilityZoneOpenstackNull               ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
