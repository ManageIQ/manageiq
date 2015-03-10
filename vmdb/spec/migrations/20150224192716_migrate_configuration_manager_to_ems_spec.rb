require "spec_helper"
require Rails.root.join("db/migrate/20150224192716_migrate_configuration_manager_to_ems")

describe MigrateConfigurationManagerToEms do
  let(:config_manager_stub) { migration_stub(:ConfigurationManager) }
  let(:config_system_stub)  { migration_stub(:ConfiguredSystem) }
  let(:config_profile_stub) { migration_stub(:ConfigurationProfile) }
  let(:ems_stub)            { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates configuration_managers to ext_management_systems" do
      manager = config_manager_stub.create!(
        :type               => "ConfigurationManagerForeman",
        :provider_id        => 99,
        :last_refresh_error => "xxx",
        :last_refresh_date  => Time.now.utc
      )
      systems = 2.times.collect do
        config_system_stub.create!(:configuration_manager_id => manager.id)
      end
      profiles = 2.times.collect do
        config_profile_stub.create!(:configuration_manager_id => manager.id)
      end

      migrate

      expect(ems_stub.count).to eq(1)
      ems = ems_stub.first
      expect(ems).to have_attributes(
        manager.attributes.slice(
          "type", "provider_id", "last_refresh_error", "last_refresh_date"
        )
      )
      expect(ems.guid).to_not be_nil

      systems.each do |s|
        expect(s.reload.configuration_manager_id).to eq(ems.id)
      end

      profiles.each do |p|
        expect(p.reload.configuration_manager_id).to eq(ems.id)
      end
    end
  end

  migration_context :down do
    it "migrates ext_management_systems to configuration_managers" do
      ems = ems_stub.create!(
        :type               => "ConfigurationManagerForeman",
        :provider_id        => 99,
        :last_refresh_error => "xxx",
        :last_refresh_date  => Time.now.utc
      )
      systems = 2.times.collect do
        config_system_stub.create!(:configuration_manager_id => ems.id)
      end
      profiles = 2.times.collect do
        config_profile_stub.create!(:configuration_manager_id => ems.id)
      end

      migrate

      expect(config_manager_stub.count).to eq(1)
      manager = config_manager_stub.first
      expect(manager).to have_attributes(
        ems.attributes.slice(
          "type", "provider_id", "last_refresh_error", "last_refresh_date"
        )
      )

      systems.each do |s|
        expect(s.reload.configuration_manager_id).to eq(manager.id)
      end

      profiles.each do |p|
        expect(p.reload.configuration_manager_id).to eq(manager.id)
      end
    end
  end
end
