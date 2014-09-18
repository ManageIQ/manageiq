require "spec_helper"
require Rails.root.join("db/migrate/20140918154013_add_provider_region_to_ext_management_systems")

describe AddProviderRegionToExtManagementSystems do
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "Updates the provider_region and hostname columns" do
      e1 = ems_stub.create!(:type => "EmsAmazon", :hostname => "us-east-1")
      e2 = ems_stub.create!(:type => "EmsAmazon", :hostname => "us-west-1")
      e3 = ems_stub.create!(:type => "EmsOther",  :hostname => "my.org")

      migrate

      e1.reload
      e2.reload
      e3.reload

      expect(e1.provider_region).to eq("us-east-1")
      expect(e1.hostname).to        be_nil
      expect(e2.provider_region).to eq("us-west-1")
      expect(e2.hostname).to        be_nil
      expect(e3.provider_region).to be_nil
      expect(e3.hostname).to        eq("my.org")
    end
  end

  migration_context :down do
    it "Updates the hostname columns" do
      e1 = ems_stub.create!(:type => "EmsAmazon", :provider_region => "us-east-1", :hostname => nil)
      e2 = ems_stub.create!(:type => "EmsAmazon", :provider_region => "us-west-1", :hostname => nil)
      e3 = ems_stub.create!(:type => "EmsOther",  :provider_region => nil,         :hostname => "my.org")

      migrate

      e1.reload
      e2.reload
      e3.reload

      expect(e1.hostname).to eq("us-east-1")
      expect(e2.hostname).to eq("us-west-1")
      expect(e3.hostname).to eq("my.org")
    end
  end
end
