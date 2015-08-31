require 'spec_helper'

describe TenantQuota do
  let(:settings) {{}}
  let(:tenant)   {Tenant.new(:domain => 'x.com', :parent => default_tenant)}

  let(:default_tenant) do
    Tenant.seed
    Tenant.default_tenant
  end

  let(:root_tenant) do
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
