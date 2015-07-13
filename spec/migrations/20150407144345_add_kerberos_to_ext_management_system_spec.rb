require "spec_helper"
require Rails.root.join("db/migrate/20150407144345_add_kerberos_to_ext_management_system.rb")

describe AddKerberosToExtManagementSystem do
  let(:reserve_stub) { MigrationSpecStubs.reserved_stub }
  let(:ems_stub)     { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "Migrates Reserves data to columns on ExtManagementSystem" do
      ems = ems_stub.create!
      reserve_stub.create!(
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :reserved      => {
          :security_protocol => "kerberos",
          :realm             => "pretendrealm"
        }
      )

      migrate

      # Expect counts
      expect(reserve_stub.count).to eq(0)
      expect(ems_stub.count).to eq(1)

      # Expect data
      expect(ems.reload.security_protocol).to eq("kerberos")
      expect(ems.reload.realm).to eq("pretendrealm")
    end
  end

  migration_context :down do
    it "Migrates Reserves data to Reserves table" do
      data = {
        :security_protocol => "kerberos",
        :realm             => "pretendrealm"
      }

      ems = ems_stub.create!(data)

      migrate

      # Expect counts
      expect(reserve_stub.count).to eq(1)
      expect(ems_stub.count).to eq(1)

      # Expect data
      r = reserve_stub.first
      expect(r.resource_id).to eq(ems.id)
      expect(r.resource_type).to eq("ExtManagementSystem")
      expect(r.reserved).to eq(data)
    end
  end
end
