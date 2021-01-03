RSpec.describe TenantQuota do
  let(:tenant) { FactoryBot.create(:tenant) }

  it "doesn't access database when unchanged model is saved" do
    m = described_class.create(:tenant => tenant, :name => :cpu_allocated, :value => 16)
    expect { m.valid? }.not_to make_database_queries
  end

  describe "#valid?" do
    it "rejects invalid name" do
      expect(described_class.new(:name => "XXX")).not_to be_valid
    end

    it "rejects missing value" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum")).not_to be_valid
    end

    it "rejects 0 warn_value" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :value => 1, :warn_value => 0)).not_to be_valid
    end

    it "defaults missing unit" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :value => 16)).to be_valid
    end

    it "accepts valid quota" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum", :value => 16)).to be_valid
    end

    it "accepts string name" do
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :unit => "fixnum", :value => 16)).to be_valid
    end

    it "accepts only one quota name per tenant" do
      first  = described_class.create(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum", :value => 1)
      second = described_class.create(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum", :value => 1)
      expect(first).to be_valid
      expect(second).not_to be_valid
      expect(second.errors.messages).to eq(:name=>["should be unique per tenant"])
    end
  end

  describe ".check_for_over_allocation" do
    let(:child_tenant) { FactoryBot.create(:tenant) }
    let(:grandchild_tenant1) { FactoryBot.create(:tenant, :parent => child_tenant) }
    let(:grandchild_tenant2) { FactoryBot.create(:tenant, :parent => child_tenant) }
    let(:great_grandchild_tenant) { FactoryBot.create(:tenant, :parent => grandchild_tenant1) }

    before do
      child_tenant
      grandchild_tenant1
      grandchild_tenant2
    end

    it "root tenant has unlimited quota" do
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :value => 1000)).to be_valid
    end

    it "child of root tenant also has unlimited quota" do
      described_class.create(:tenant => tenant, :name => "cpu_allocated", :value => 10)
      expect(described_class.new(:tenant => child_tenant, :name => "cpu_allocated", :value => 1000)).to be_valid
    end

    context "grandchild tenant" do
      it "cannot have less quota than the amount given to children" do
        described_class.create(:tenant => great_grandchild_tenant, :name => "cpu_allocated", :value => 10)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 9)).not_to be_valid
      end

      it "cannot have less quota than the amount that has already been used" do
        nq = described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)
        allow(nq).to receive_messages(:used => 2)
        expect(nq).not_to be_valid
      end
    end

    context "grandchild tenant, parent with infinity(undefined) quota" do
      it "can have unlimited quota" do
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 1000)).to be_valid
      end
    end

    context "grandchild tenant, parent over allocated" do
      it "cannot have more quota than the parent has available to allocate" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 6)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has used up its available" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)

        allow_any_instance_of(described_class).to receive_messages(:used => 5)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has allocated it to a different child" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        described_class.create!(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 5)
        expect(described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has used and has allocated it to a different child" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        described_class.create!(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 3)

        allow_any_instance_of(described_class).to receive_messages(:used => 2)
        expect(described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "can give quota that the parent has available to allocate when parent used and allocated is less than the total quota of the parent" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 10)
        described_class.create!(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 3)
        allow_any_instance_of(described_class).to receive(:used).and_return(6)

        nq = described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)
        allow(nq).to receive(:used).and_return(0)
        expect(nq).to be_valid
      end
    end
  end

  describe "#format" do
    it "has cpu" do
      expect(FactoryBot.build(:tenant_quota_cpu).format).to eq("general_number_precision_0")
    end
  end

  describe "#default_unit" do
    it "has cpu" do
      expect(FactoryBot.build(:tenant_quota_cpu).default_unit).to eq("fixnum")
    end
  end

  context "formatted tenant quota values" do
    include Spec::Support::QuotaHelper

    let(:child_tenant) { FactoryBot.create(:tenant, :parent => @tenant) }

    let(:child_tenant_quota_cpu)       { FactoryBot.create(:tenant_quota_cpu, :tenant => child_tenant) }
    let(:child_tenant_quota_mem)       { FactoryBot.create(:tenant_quota_mem, :tenant => child_tenant) }
    let(:child_tenant_quota_storage)   { FactoryBot.create(:tenant_quota_storage, :tenant => child_tenant) }
    let(:child_tenant_quota_vms)       { FactoryBot.create(:tenant_quota_vms, :tenant => child_tenant) }
    let(:child_tenant_quota_templates) { FactoryBot.create(:tenant_quota_templates, :tenant => child_tenant) }

    let(:tenant_quota_cpu) { FactoryBot.create(:tenant_quota_cpu, :tenant => child_tenant, :value => 2) }
    let(:tenant_quota_mem) { FactoryBot.create(:tenant_quota_mem, :tenant => child_tenant, :value => 4_294_967_296) }

    let(:tenant_quota_storage) do
      FactoryBot.create(:tenant_quota_storage, :tenant => child_tenant, :value => 4_294_967_296)
    end

    let(:tenant_quota_vms)       { FactoryBot.create(:tenant_quota_vms, :tenant => child_tenant, :value => 4) }
    let(:tenant_quota_templates) { FactoryBot.create(:tenant_quota_templates, :tenant => child_tenant, :value => 4) }

    before do
      setup_model
      @tenant.tenant_quotas = [tenant_quota_cpu, tenant_quota_mem, tenant_quota_storage, tenant_quota_vms,
                               tenant_quota_templates]
      child_tenant.tenant_quotas = [child_tenant_quota_cpu, child_tenant_quota_mem, child_tenant_quota_storage,
                                    child_tenant_quota_vms, child_tenant_quota_templates]
    end

    describe "#total" do
      it "displays entered quota value for 'Allocated Virtual CPUs' quota" do
        expect(tenant_quota_cpu.total).to eq(2)
      end

      it "displays entered quota value for 'Allocated Memory in GB' quota" do
        expect(tenant_quota_mem.total).to eq(4.0 * 1.gigabyte)
      end

      it "displays entered quota value for 'Allocated Storage in GB' quota" do
        expect(tenant_quota_storage.total).to eq(4.0 * 1.gigabyte)
      end

      it "displays entered quota value for 'Allocated Number of Virtual Machines' quota" do
        expect(tenant_quota_vms.total).to eq(4)
      end

      it "displays entered quota value for 'Allocated Number of Templates' quota" do
        expect(tenant_quota_templates.total).to eq(4)
      end
    end

    describe "#used" do
      it "displays used resources 'Allocated Virtual CPUs' quota" do
        expect(tenant_quota_cpu.used).to eq(0)
      end

      it "displays used resources for 'Allocated Memory in GB' quota" do
        expect(tenant_quota_mem.used).to eq(1.0 * 1.gigabyte)
      end

      it "displays used resources for 'Allocated Storage in GB' quota" do
        expect(tenant_quota_storage.used).to eq(1_000_000.0)
      end

      it "displays used resources for 'Allocated Number of Virtual Machines' quota" do
        expect(tenant_quota_vms.used).to eq(1)
      end

      it "displays used resources for 'Allocated Number of Templates' quota" do
        expect(tenant_quota_templates.used).to eq(1)
      end
    end

    describe "#allocated" do
      it "displays allocated resources for 'Allocated Virtual CPUs' quota" do
        expect(tenant_quota_cpu.allocated).to eq(16)
      end

      it "displays allocated resources for 'Allocated Memory in GB' quota" do
        expect(tenant_quota_mem.allocated).to eq(2.0 * 1.gigabyte)
      end

      it "displays allocated resources for 'Allocated Storage in GB' quota" do
        expect(tenant_quota_storage.allocated).to eq(2.0 * 1.gigabyte)
      end

      it "displays allocated resources for 'Allocated Number of Virtual Machines' quota" do
        expect(tenant_quota_vms.allocated).to eq(2)
      end

      it "displays allocated resources for 'Allocated Number of Templates' quota" do
        expect(tenant_quota_templates.allocated).to eq(2)
      end
    end

    describe "#available" do
      it "displays available resources for 'Allocated Virtual CPUs' quota" do
        expect(tenant_quota_cpu.available).to eq(-14.0)
      end

      it "displays available resources for 'Allocated Memory in GB' quota" do
        expect(tenant_quota_mem.available).to eq(1.0 * 1.gigabyte)
      end

      it "displays available resources for 'Allocated Storage in GB' quota" do
        expect(tenant_quota_storage.available).to eq(2.0 * 1.gigabytes - 1_000_000.0)
      end

      it "displays available resources for 'Allocated Number of Virtual Machines' quota" do
        expect(tenant_quota_vms.available).to eq(1.0)
      end

      it "displays available resources for 'Allocated Number of Templates' quota" do
        expect(tenant_quota_templates.available).to eq(1.0)
      end
    end
  end

  describe ".format_quota_value" do
    let(:quota_name) { "cpu_allocated" }
    let(:quota_description) { "Allocated Virtual CPUs" }

    it "returns quota description if field to format is 'tenant_quotas.name'" do
      expect(described_class.format_quota_value("tenant_quotas.name", "something", quota_name)).to eq(quota_description)
    end

    it "returns quota description if field to format is 'tenant_quotas.description'" do
      expect(described_class.format_quota_value("tenant_quotas.description", "something", quota_name)).to eq(quota_description)
    end
  end

  describe "#quota_hash" do
    it "has cpu_allocated attributes" do
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Virtual CPUs"
      )
    end

    it "has vms_allocated attributes" do
      expect(described_class.new(:tenant => tenant, :name => "vms_allocated", :value => 20).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 20.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Number of Virtual Machines"
      )
    end

    it "has mem_allocated attributes" do
      expect(described_class.new(:tenant => tenant, :name => "mem_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Memory in GB"
      )
    end

    it "has nil attributes" do
      expect(described_class.new(:tenant => tenant, :name => "storage_allocated").tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => nil,
        :warn_value    => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Storage in GB"
      )
    end
  end

  describe ".destroy_missing" do
    let(:tenant2) { FactoryBot.create(:tenant) }

    it "removes extra quotas only from object in question" do
      tenant.tenant_quotas.create(:name => :vms_allocated, :value => 20)
      tenant.tenant_quotas.create(:name => :mem_allocated, :value => 4096)
      tenant2.tenant_quotas.create(:name => :cpu_allocated, :value => 8)

      tenant.tenant_quotas.destroy_missing([:vms_allocated])
      expect(tenant.tenant_quotas.count).to eq(1)
      expect(tenant2.tenant_quotas.count).to eq(1)
    end
  end
end
