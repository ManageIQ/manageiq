describe ExtManagementSystem do
  it ".model_name_from_emstype" do
    described_class.leaf_subclasses.each do |klass|
      expect(described_class.model_name_from_emstype(klass.ems_type)).to eq(klass.name)
    end
    expect(described_class.model_name_from_emstype('foo')).to be_nil
  end

  it ".create_discovered_ems" do
    ost = OpenStruct.new(:ipaddr => "0.0.0.0", :hypervisor => [:virtualcenter])

    allow(MiqServer).to receive(:my_server).and_return(
      double("MiqServer", :zone => double("Zone", :name => "foo", :id => 1)))
    expect(AuditEvent).to receive(:success)

    described_class.create_discovered_ems(ost)
  end

  let(:all_types_and_descriptions) do
    {
      "ansible_tower_configuration" => "Ansible Tower Configuration",
      "atomic"                      => "Atomic",
      "atomic_enterprise"           => "Atomic Enterprise",
      "azure"                       => "Azure",
      "azure_network"               => "Azure Network",
      "ec2"                         => "Amazon EC2",
      "ec2_network"                 => "Amazon EC2 Network",
      "foreman_configuration"       => "Foreman Configuration",
      "foreman_provisioning"        => "Foreman Provisioning",
      "gce"                         => "Google Compute Engine",
      "gce_network"                 => "Google Network",
      "hawkular"                    => "Hawkular",
      "kubernetes"                  => "Kubernetes",
      "openshift"                   => "OpenShift Origin",
      "openshift_enterprise"        => "OpenShift Enterprise",
      "openstack"                   => "OpenStack",
      "openstack_infra"             => "OpenStack Platform Director",
      "openstack_network"           => "OpenStack Network",
      "rhevm"                       => "Red Hat Enterprise Virtualization Manager",
      "scvmm"                       => "Microsoft System Center VMM",
      "vmwarews"                    => "VMware vCenter",
    }
  end

  it ".types" do
    expect(described_class.types).to match_array(all_types_and_descriptions.keys)
  end

  it ".supported_types" do
    expect(described_class.supported_types).to match_array(all_types_and_descriptions.keys)
  end

  describe ".supported_types_and_descriptions_hash" do
    it "with default permissions" do
      expect(described_class.supported_types_and_descriptions_hash).to eq(all_types_and_descriptions)
    end

    it "with removed permissions" do
      stub_vmdb_permission_store_with_types(["ems-type:vmwarews"]) do
        expect(described_class.supported_types_and_descriptions_hash).to eq("vmwarews" => "VMware vCenter")
      end
    end

    it "permissions.tmpl.yml should contain all EMS types" do
      types = YAML.load_file(Rails.root.join("config/permissions.tmpl.yml"))
      # atomic is no longer in the list of permissions, because they should be faded out
      # and new container managers should be openshift. Until they are fully removed from the
      # codebase: https://github.com/ManageIQ/manageiq/issues/8612
      types += %w(ems-type:atomic ems-type:atomic_enterprise)
      stub_vmdb_permission_store_with_types(types) do
        expect(described_class.supported_types_and_descriptions_hash).to eq(all_types_and_descriptions)
      end
    end
  end

  it ".ems_infra_discovery_types" do
    expected_types = %w(scvmm rhevm virtualcenter)

    expect(described_class.ems_infra_discovery_types).to match_array(expected_types)
  end

  it ".ems_cloud_discovery_types" do
    discovery_type = {'amazon' => 'ec2'}
    described_class.register_cloud_discovery_type(discovery_type)
    expect(described_class.ems_cloud_discovery_types).to include(discovery_type)
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

  context "with multiple endpoints" do
    let(:ems) { FactoryGirl.build(:ems_openstack, :hostname => "example.org") }
    before { ems.add_connection_configuration_by_role(:endpoint => {:role => "amqp", :hostname => "amqp.example.org"}) }

    it "will contain seperate ampq endpoint" do
      expect(ems.default_endpoint.hostname).to eq "example.org"
      expect(ems.connection_configuration_by_role("amqp").endpoint.hostname).to eq "amqp.example.org"
    end

    it "will contain multiple endpoints" do
      expected_endpoints = ["example.org", "amqp.example.org"]
      expect(ems.hostnames).to match_array(expected_endpoints)
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

  context "with virtual totals" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware)
      (1..2).each { |i| FactoryGirl.create(:vm_vmware, :ext_management_system => @ems, :name => "vm_#{i}") }
    end

    it "#total_vms_on" do
      expect(@ems.total_vms_on).to eq(2)
    end

    it "#total_vms_off" do
      expect(@ems.total_vms_off).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "poweredOff") }
      expect(@ems.total_vms_off).to eq(2)
    end

    it "#total_vms_unknown" do
      expect(@ems.total_vms_unknown).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "unknown") }
      expect(@ems.total_vms_unknown).to eq(2)
    end

    it "#total_vms_never" do
      expect(@ems.total_vms_never).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "never") }
      expect(@ems.total_vms_never).to eq(2)
    end

    it "#total_vms_suspended" do
      expect(@ems.total_vms_suspended).to eq(0)

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "suspended") }
      expect(@ems.total_vms_suspended).to eq(2)
    end

    %w(total_vms_on total_vms_off total_vms_unknown total_vms_never total_vms_suspended).each do |vcol|
      it "should have virtual column #{vcol} " do
        expect(described_class).to have_virtual_column "#{vcol}", :integer
      end
    end

    it "#total_vms" do
      expect(@ems.total_vms).to eq(2)
    end

    it "#total_vms_and_templates" do
      FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      expect(@ems.total_vms_and_templates).to eq(3)
    end

    it "#total_miq_templates" do
      FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      expect(@ems.total_miq_templates).to eq(1)
    end
  end

  describe "#total_clusters" do
    it "knows it has none" do
      ems = FactoryGirl.create(:ems_vmware)
      expect(ems.total_clusters).to eq(0)
    end

    it "knows it has one" do
      ems = FactoryGirl.create(:ems_vmware)
      FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
      expect(ems.total_clusters).to eq(1)
    end
  end

  context "validates" do
    before do
      Zone.seed
    end

    context "within the same sub-classes" do
      described_class.leaf_subclasses.each do |ems|
        next if ems == ManageIQ::Providers::Amazon::CloudManager # Amazon is tested in ems_amazon_spec.rb
        # TODO(lsmola) NetworkManager, test this if NetworkManager becomes not dependent on cloud manager
        next if [ManageIQ::Providers::Openstack::NetworkManager,
                 ManageIQ::Providers::Amazon::NetworkManager,
                 ManageIQ::Providers::Azure::NetworkManager,
                 ManageIQ::Providers::Google::NetworkManager].include? ems
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
        # TODO(lsmola) NetworkManager, test this when we have a standalone NetworkManager
        next if [ManageIQ::Providers::Openstack::NetworkManager,
                 ManageIQ::Providers::Amazon::NetworkManager,
                 ManageIQ::Providers::Azure::NetworkManager,
                 ManageIQ::Providers::Google::NetworkManager].include? ems

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
