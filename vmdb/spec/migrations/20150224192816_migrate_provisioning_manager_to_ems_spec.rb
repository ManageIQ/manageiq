require "spec_helper"
require Rails.root.join("db/migrate/20150224192816_migrate_provisioning_manager_to_ems")

describe MigrateProvisioningManagerToEms do
  let(:prov_manager_stub) { migration_stub(:ProvisioningManager) }
  let(:os_flavor_stub)    { migration_stub(:OperatingSystemFlavor) }
  let(:cust_script_stub)  { migration_stub(:CustomizationScript) }
  let(:ems_stub)          { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates provisioning_managers to ext_management_systems" do
      manager = prov_manager_stub.create!(
        :type               => "ProvisioningManagerForeman",
        :provider_id        => 99,
        :last_refresh_error => "xxx",
        :last_refresh_date  => Time.now.utc
      )
      os_flavors = 2.times.collect do
        os_flavor_stub.create!(:provisioning_manager_id => manager.id)
      end
      scripts = 2.times.collect do
        cust_script_stub.create!(:provisioning_manager_id => manager.id)
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

      os_flavors.each do |f|
        expect(f.reload.provisioning_manager_id).to eq(ems.id)
      end

      scripts.each do |s|
        expect(s.reload.provisioning_manager_id).to eq(ems.id)
      end
    end
  end

  migration_context :down do
    it "migrates ext_management_systems to provisioning_managers" do
      ems = ems_stub.create!(
        :type               => "ProvisioningManagerForeman",
        :provider_id        => 99,
        :last_refresh_error => "xxx",
        :last_refresh_date  => Time.now.utc
      )
      os_flavors = 2.times.collect do
        os_flavor_stub.create!(:provisioning_manager_id => ems.id)
      end
      scripts = 2.times.collect do
        cust_script_stub.create!(:provisioning_manager_id => ems.id)
      end

      migrate

      expect(prov_manager_stub.count).to eq(1)
      manager = prov_manager_stub.first
      expect(manager).to have_attributes(
        ems.attributes.slice(
          "type", "provider_id", "last_refresh_error", "last_refresh_date"
        )
      )

      os_flavors.each do |f|
        expect(f.reload.provisioning_manager_id).to eq(manager.id)
      end

      scripts.each do |s|
        expect(s.reload.provisioning_manager_id).to eq(manager.id)
      end
    end
  end
end
