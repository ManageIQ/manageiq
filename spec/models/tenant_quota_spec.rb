require 'spec_helper'

describe TenantQuota do
  let(:settings) { {} }
  let(:tenant) { Tenant.new(:domain => 'x.com', :parent => default_tenant) }

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
      expect {
        described_class.create!(:name => "XXX")
      }.to raise_error
    end

    it "rejects missing value" do
      expect {
        described_class.create!(:name => :cpu_allocated, :unit => "mhz")
      }.to raise_error
    end

    it "rejects missing unit" do
      expect {
        described_class.create!(:name => :cpu_allocated, :value => 4096)
      }.to raise_error
    end
  end

  describe ".set" do
    it "adds new quotas" do
      described_class.set(default_tenant, :cpu_allocated => {:value => 1024}, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas.order(:name)
      expect(tq.length).to eql 3

      tq_cpu = tq[0]
      expect(tq_cpu.name).to eql "cpu_allocated"
      expect(tq_cpu.unit).to eql "mhz"
      expect(tq_cpu.format).to eql "mhz"
      expect(tq_cpu.value).to eql 1024.0

      tq_mem = tq[1]
      expect(tq_mem.name).to eql "mem_allocated"
      expect(tq_mem.unit).to eql "bytes"
      expect(tq_mem.format).to eql "gigabytes_human"
      expect(tq_mem.value).to eql 4096.0


      tq_vms = tq[2]
      expect(tq_vms.name).to eql "vms_allocated"
      expect(tq_vms.unit).to eql "fixnum"
      expect(tq_vms.format).to eql "general_number_precision_0"
      expect(tq_vms.value).to eql 20.0
    end

    it "updates existing quotas" do
      described_class.set(default_tenant, :vms_allocated => {:value => 20})

      tq = described_class.last
      expect(tq.value).to eql 20.0

      described_class.set(default_tenant, :vms_allocated => {:value => 40})

      tq.reload
      expect(tq.value).to eql 40.0
    end

    it "deletes existing quotas" do
      described_class.set(default_tenant, :cpu_allocated => {:value => 1024}, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 3

      described_class.set(default_tenant, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 2
      expect(tq.map(&:name).sort).to eql ['mem_allocated', 'vms_allocated']
    end
  end

  describe ".get" do
    it "gets existing quotas" do
      described_class.set(default_tenant, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      expected =       {
          :vms_allocated     => {
            :unit          => "fixnum",
            :value         => 20.0,
            :format        => "general_number_precision_0",
            :text_modifier => "Count",
            :description   => "Allocated Number of Virtual Machines"
          },
          :mem_allocated     => {
            :unit          => "bytes",
            :value         => 4096.0,
            :format        => "gigabytes_human",
            :text_modifier => "GB",
            :description   => "Allocated Memory in GB"
          },
          :storage_allocated => {
            :unit          => :bytes,
            :value         => nil,
            :format        => :gigabytes_human,
            :text_modifier => "GB",
            :description   => "Allocated Storage in GB"
          }
      }

      expect(described_class.get(default_tenant)[:vms_allocated]).to     eql expected[:vms_allocated]
      expect(described_class.get(default_tenant)[:mem_allocated]).to     eql expected[:mem_allocated]
      expect(described_class.get(default_tenant)[:storage_allocated]).to eql expected[:storage_allocated]
    end
  end
end
