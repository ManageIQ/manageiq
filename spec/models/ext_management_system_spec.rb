describe ExtManagementSystem do
  it ".model_name_from_emstype" do
    described_class.leaf_subclasses.each do |klass|
      expect(described_class.model_name_from_emstype(klass.ems_type)).to eq(klass.name)
    end
    expect(described_class.model_name_from_emstype('foo')).to be_nil
  end

  let(:all_types) do
    %w(
      ec2
      foreman_configuration
      foreman_provisioning
      gce
      hawkular
      kubernetes
      openshift
      atomic
      openshift_enterprise
      atomic_enterprise
      openstack
      openstack_infra
      rhevm
      scvmm
      vmwarews
      azure
      ansible_tower_configuration
    )
  end

  it ".types" do
    expect(described_class.types).to match_array(all_types)
  end

  it ".supported_types" do
    expect(described_class.supported_types).to match_array(all_types)
  end

  it ".ems_infra_discovery_types" do
    expected_types = %w(scvmm rhevm virtualcenter)

    expect(described_class.ems_infra_discovery_types).to match_array(expected_types)
  end

  it ".ems_cloud_discovery_types" do
    expected_types = {"azure" => "azure", "amazon" => "ec2"}
    expect(described_class.ems_cloud_discovery_types).to eq(expected_types)
  end

  context "#ipaddress / #ipaddress=" do
    it "will delegate to the default endpoint" do
      ems = FactoryGirl.build(:ems_vmware, :ipaddress => "1.2.3.4")
      expect(ems.default_endpoint.ipaddress).to eq "1.2.3.4"
    end

    it "with nil" do
      ems = FactoryGirl.build(:ems_vmware, :ipaddress => nil)
      expect(ems.default_endpoint.ipaddress).to be_nil
    end
  end

  context "#hostname / #hostname=" do
    it "will delegate to the default endpoint" do
      ems = FactoryGirl.build(:ems_vmware, :hostname => "example.org")
      expect(ems.default_endpoint.hostname).to eq "example.org"
    end

    it "with nil" do
      ems = FactoryGirl.build(:ems_vmware, :hostname => nil)
      expect(ems.default_endpoint.hostname).to be_nil
    end
  end

  context "#port, #port=" do
    it "will delegate to the default endpoint" do
      ems = FactoryGirl.build(:ems_vmware, :port => 1234)
      expect(ems.default_endpoint.port).to eq 1234
    end

    it "will delegate a string to the default endpoint" do
      ems = FactoryGirl.build(:ems_vmware, :port => "1234")
      expect(ems.default_endpoint.port).to eq 1234
    end

    it "with nil" do
      ems = FactoryGirl.build(:ems_vmware, :port => nil)
      expect(ems.default_endpoint.port).to be_nil
    end
  end

  context "with two small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @zone2 = FactoryGirl.create(:small_environment)
    end

    it "refresh_all_ems_timer will refresh for all emses in zone1" do
      @ems1 = @zone1.ext_management_systems.first
      allow(MiqServer).to receive(:my_server).and_return(@zone1.miq_servers.first)
      expect(described_class).to receive(:refresh_ems).with([@ems1.id], true)
      described_class.refresh_all_ems_timer
    end

    it "refresh_all_ems_timer will refresh for all emses in zone2" do
      @ems2 = @zone2.ext_management_systems.first
      allow(MiqServer).to receive(:my_server).and_return(@zone2.miq_servers.first)
      expect(described_class).to receive(:refresh_ems).with([@ems2.id], true)
      described_class.refresh_all_ems_timer
    end
  end

  context "with virtual columns" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware)
      (1..5).each { |i| FactoryGirl.create(:vm_vmware, :ext_management_system => @ems, :name => "vm_#{i}") }
    end

    it "#total_vms_on" do
      expect(@ems.total_vms_on).to eq(5)
    end

    it "#total_vms_off" do
      expect(@ems.total_vms_off).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "poweredOff") }
      expect(@ems.total_vms_off).to eq(5)
    end

    it "#total_vms_unknown" do
      expect(@ems.total_vms_unknown).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "unknown") }
      expect(@ems.total_vms_unknown).to eq(5)
    end

    it "#total_vms_never" do
      expect(@ems.total_vms_never).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "never") }
      expect(@ems.total_vms_never).to eq(5)
    end

    it "#total_vms_suspended" do
      expect(@ems.total_vms_suspended).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "suspended") }
      expect(@ems.total_vms_suspended).to eq(5)
    end

    %w(total_vms_on total_vms_off total_vms_unknown total_vms_never total_vms_suspended).each do |vcol|
      it "should have virtual column #{vcol} " do
        expect(described_class).to have_virtual_column "#{vcol}", :integer
      end
    end
  end

  context "validates" do
    before do
      Zone.seed
    end

    context "within the same sub-classes" do
      described_class.leaf_subclasses.each do |ems|
        next if ems == ManageIQ::Providers::Amazon::CloudManager # Amazon is tested in ems_amazon_spec.rb
        t = ems.name.underscore

        context t do
          it "duplicate name" do
            expect { FactoryGirl.create(t, :name => "ems_1") }.to_not raise_error
            expect { FactoryGirl.create(t, :name => "ems_1") }.to     raise_error(ActiveRecord::RecordInvalid)
          end

          if ems.new.hostname_required?
            it "duplicate hostname" do
              expect { FactoryGirl.create(t, :hostname => "ems_1") }.to_not raise_error
              expect { FactoryGirl.create(t, :hostname => "ems_1") }.to     raise_error(ActiveRecord::RecordInvalid)
              expect { FactoryGirl.create(t, :hostname => "EMS_1") }.to     raise_error(ActiveRecord::RecordInvalid)
            end

            it "blank hostname" do
              expect { FactoryGirl.create(t, :hostname => "") }.to raise_error(ActiveRecord::RecordInvalid)
            end

            it "nil hostname" do
              expect { FactoryGirl.create(t, :hostname => nil) }.to raise_error(ActiveRecord::RecordInvalid)
            end
          end
        end
      end
    end

    context "across sub-classes, from vmware to" do
      before do
        @ems_vmware = FactoryGirl.create(:ems_vmware)
      end

      described_class.leaf_subclasses.collect do |ems|
        t = ems.name.underscore

        context t do
          it "duplicate name" do
            expect do
              FactoryGirl.create(t, :name => @ems_vmware.name)
            end.to raise_error(ActiveRecord::RecordInvalid)
          end

          it "duplicate hostname" do
            manager = FactoryGirl.build(t, :hostname => @ems_vmware.hostname)

            if manager.hostname_required?
              expect { manager.save! }.to raise_error(ActiveRecord::RecordInvalid)
            else
              expect { manager.save! }.to_not raise_error
            end
          end
        end
      end
    end

    context "across tenants" do
      before do
        tenant1  = Tenant.seed
        @tenant2 = FactoryGirl.create(:tenant, :parent => tenant1)
        @ems     = FactoryGirl.create(:ems_vmware, :tenant => tenant1)
      end

      it "allowing duplicate name" do
        expect do
          FactoryGirl.create(:ems_vmware, :name => @ems.name, :tenant => @tenant2)
        end.to_not raise_error
      end

      it "not allowing duplicate hostname" do
        expect do
          FactoryGirl.create(:ems_vmware, :hostname => @ems.hostname, :tenant => @tenant2)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  context "#tenant" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant" do
      ems = FactoryGirl.create(:ext_management_system, :tenant => tenant)
      expect(tenant.ext_management_systems).to include(ems)
    end
  end
end
