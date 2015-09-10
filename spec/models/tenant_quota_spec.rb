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

  describe "#format" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).format).to eq("mhz")
    end
  end

  describe "#default_unit" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).default_unit).to eq("mhz")
    end
  end
end
