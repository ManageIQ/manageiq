require 'spec_helper'

describe TenantQuota do
  let(:tenant) { FactoryGirl.create(:tenant, :parent => root_tenant) }

  let(:root_tenant) do
    MiqRegion.seed
    Tenant.seed
    Tenant.root_tenant
  end

  context "validations" do
    it "rejects invalid name" do
      expect { described_class.create!(:name => "XXX") }.to raise_error
    end

    it "rejects missing value" do
      expect { described_class.create!(:name => :cpu_allocated, :unit => "mhz") }.to raise_error
    end

    it "rejects missing unit" do
      expect { described_class.create!(:name => :cpu_allocated, :value => 4096) }.to raise_error
    end
  end

end
