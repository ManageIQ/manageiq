class NamespaceEmsOpenstackAvailabilityZonesNull < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    AvailabilityZoneOpenstackNull               ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull
  )]

  def change
    # Fix issues where future migrations could be named incorrectly due to the
    #   bad naming of this particular migration
    bad = Pathname.glob(Rails.root.join("db/migrate/20151435*")).first
    raise ActiveRecord::IllegalMigrationNameError.new(bad) if bad

    return if previously_migrated_as?("20151435234622")

    rename_class_references(NAME_MAP)
  end
end
