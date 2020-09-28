RSpec.describe ExtManagementSystem do
  subject { FactoryBot.create(:ext_management_system) }

  include_examples "AggregationMixin"
  include_examples "MiqPolicyMixin"

  describe ".with_tenant" do
    # tenant_root
    #   \___ tenant_eye_bee_em (service_template_eye_bee_em)
    #     \__ subtenant_tenant_eye_bee_em_1 (ems_1)
    #       \__ subtenant_tenant_eye_bee_em_1_1 (ems_1_1, ems_1_1_a)
    #     \__ subtenant_tenant_eye_bee_em_3  (ems_3, ems_3_a)

    let!(:tenant_root) { Tenant.seed }

    let!(:tenant_eye_bee_em) { FactoryBot.create(:tenant, :parent => tenant_root) }
    let!(:subtenant_tenant_eye_bee_em_1) { FactoryBot.create(:tenant, :parent => tenant_eye_bee_em) }
    let!(:subtenant_tenant_eye_bee_em_3) { FactoryBot.create(:tenant, :parent => tenant_eye_bee_em) }

    let!(:subtenant_tenant_eye_bee_em_1_1) { FactoryBot.create(:tenant, :parent => subtenant_tenant_eye_bee_em_1) }

    let!(:ems_eye_bee_em) { FactoryBot.create(:ext_management_system, :tenant => tenant_eye_bee_em) }
    let!(:ems_1)          { FactoryBot.create(:ext_management_system, :tenant => subtenant_tenant_eye_bee_em_1) }
    let!(:ems_3)          { FactoryBot.create(:ext_management_system, :tenant => subtenant_tenant_eye_bee_em_3) }
    let!(:ems_3_a)        { FactoryBot.create(:ext_management_system, :tenant => subtenant_tenant_eye_bee_em_3) }
    let!(:ems_1_1)        { FactoryBot.create(:ext_management_system, :tenant => subtenant_tenant_eye_bee_em_1_1) }
    let!(:ems_1_1_a)      { FactoryBot.create(:ext_management_system, :tenant => subtenant_tenant_eye_bee_em_1_1) }

    it "lists ancestor service templates" do
      expect(ExtManagementSystem.with_tenant(subtenant_tenant_eye_bee_em_1_1.id).ids).to match_array([ems_1_1.id, ems_1_1_a.id, ems_1.id, ems_eye_bee_em.id])
      expect(ExtManagementSystem.with_tenant(subtenant_tenant_eye_bee_em_3.id).ids).to match_array([ems_3.id, ems_3_a.id, ems_eye_bee_em.id])
    end
  end

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

  it ".types" do
    expect(described_class.types).to include("ec2", "vmwarews")
  end

  describe ".supported_types" do
    it "with default permissions" do
      expect(described_class.supported_types).to include("ec2", "vmwarews")
    end

    it "with removed permissions" do
      allow(Vmdb::PermissionStores.instance).to receive(:supported_ems_type?).and_return(true)
      allow(Vmdb::PermissionStores.instance).to receive(:supported_ems_type?).with("vmwarews").and_return(false)
      expect(described_class.supported_types).not_to include("vmwarews")
    end
  end

  describe ".supported_types_and_descriptions_hash" do
    it "with default permissions" do
      expect(described_class.supported_types_and_descriptions_hash).to include("vmwarews" => "VMware vCenter")
    end

    it "with removed permissions" do
      allow(Vmdb::PermissionStores.instance).to receive(:supported_ems_type?).and_return(true)
      allow(Vmdb::PermissionStores.instance).to receive(:supported_ems_type?).with("vmwarews").and_return(false)
      expect(described_class.supported_types_and_descriptions_hash).to_not include("vmwarews")
    end
  end

  it "does access database when unchanged model is saved" do
    r = FactoryBot.create(:ems_vmware)
    expect { r.valid? }.to make_database_queries(:count => 3)
  end

  it ".ems_infra_discovery_types" do
    expected_types = %w(scvmm rhevm virtualcenter openstack_infra)

    expect(described_class.ems_infra_discovery_types).to match_array(expected_types)
  end

  it ".with_eligible_manager_types" do
    v = FactoryBot.create(:ems_vmware)
    r = FactoryBot.create(:ems_redhat)

    expect(described_class.with_eligible_manager_types([v.class, r.class]).count).to eq(2)
    expect(described_class.with_eligible_manager_types([v.class]).count).to eq(1)
    expect(described_class.with_eligible_manager_types(r.class).count).to eq(1)
  end

  it "validates type" do
    v = FactoryBot.create(:ems_vmware)
    e = FactoryBot.create(:ext_management_system)
    s = FactoryBot.create(:ems_storage)

    expect([v.valid?, v.emstype]).to eq([true, 'vmwarews'])
    expect([e.valid?, e.emstype]).to eq([true, 'vmwarews'])
    expect([s.valid?, s.emstype]).to eq([true, 'swift'])
    expect { ManageIQ::Providers::BaseManager.new(:hostname => "abc", :name => "abc", :zone => FactoryBot.build(:zone)).validate! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { ManageIQ::Providers::InfraManager.new(:hostname => "abc", :name => "abc", :zone => FactoryBot.build(:zone)).validate! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { ManageIQ::Providers::CloudManager.new(:hostname => "abc", :name => "abc", :zone => FactoryBot.build(:zone)).validate! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { ManageIQ::Providers::AutomationManager.new(:hostname => "abc", :name => "abc", :zone => FactoryBot.build(:zone)).validate! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(ManageIQ::Providers::Vmware::InfraManager.new(:hostname => "abc", :name => "abc", :zone => FactoryBot.build(:zone)).validate!).to eq(true)

    zone = FactoryBot.create(:zone)
    foreman_provider = ManageIQ::Providers::Foreman::Provider.new(:name => "abc", :zone => zone, :url => "https://abc")
    expect(ManageIQ::Providers::Foreman::ConfigurationManager.new(:provider => foreman_provider, :name => "abc", :zone => zone).validate!).to eq(true)
    expect(ManageIQ::Providers::Foreman::ProvisioningManager.new(:provider => foreman_provider, :name => "abc", :zone => zone).validate!).to eq(true)
  end

  context "#ipaddress / #ipaddress=" do
    it "will delegate to the default endpoint" do
      ems = FactoryBot.build(:ems_vmware, :ipaddress => "1.2.3.4")
      expect(ems.default_endpoint.ipaddress).to eq "1.2.3.4"
    end

    it "with nil" do
      ems = FactoryBot.build(:ems_vmware, :ipaddress => nil)
      expect(ems.default_endpoint.ipaddress).to be_nil
    end
  end

  it "#total_storages" do
    ems = FactoryBot.create(:ems_vmware)

    storage1 = FactoryBot.create(:storage, :ems_id => ems.id)
    storage2 = FactoryBot.create(:storage, :ems_id => ems.id)

    FactoryBot.create(
      :host_vmware,
      :storages              => [storage1, storage2],
      :ext_management_system => ems
    )

    FactoryBot.create(
      :host_vmware,
      :storages              => [storage2],
      :ext_management_system => ems
    )

    expect(ems.total_storages).to eq 2
  end

  context "#hostname / #hostname=" do
    it "will delegate to the default endpoint" do
      ems = FactoryBot.build(:ems_vmware, :hostname => "example.org")
      expect(ems.default_endpoint.hostname).to eq "example.org"
    end

    it "with nil" do
      ems = FactoryBot.build(:ems_vmware, :hostname => nil)
      expect(ems.default_endpoint.hostname).to be_nil
    end
  end

  context "#port, #port=" do
    it "will delegate to the default endpoint" do
      ems = FactoryBot.build(:ems_vmware, :port => 1234)
      expect(ems.default_endpoint.port).to eq 1234
    end

    it "will delegate a string to the default endpoint" do
      ems = FactoryBot.build(:ems_vmware, :port => "1234")
      expect(ems.default_endpoint.port).to eq 1234
    end

    it "with nil" do
      ems = FactoryBot.build(:ems_vmware, :port => nil)
      expect(ems.default_endpoint.port).to be_nil
    end
  end

  context "with multiple endpoints" do
    let(:ems) { FactoryBot.build(:ems_openstack, :hostname => "example.org") }
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

  context "with multiple endpoints using connection_configurations" do
    let(:ems) do
      FactoryBot.build(:ems_openstack,
                        :hostname                  => "example.org",
                        :connection_configurations => [{:endpoint => {:role     => "amqp",
                                                                      :hostname => "amqp.example.org"}}])
    end

    it "will contain seperate ampq endpoint" do
      expect(ems.default_endpoint.hostname).to eq "example.org"
      expect(ems.connection_configuration_by_role("amqp").endpoint.hostname).to eq "amqp.example.org"
    end

    it "will contain multiple endpoints" do
      expected_endpoints = ["example.org", "amqp.example.org"]
      expect(ems.hostnames).to match_array(expected_endpoints)
    end
  end

  context "with multiple endpoints using connection_configurations (string keys)" do
    let(:ems) do
      FactoryBot.build(:ems_openstack,
                        "hostname"                  => "example.org",
                        "connection_configurations" => [{"endpoint" => {"role"     => "amqp",
                                                                        "hostname" => "amqp.example.org"}}])
    end

    it "will contain seperate ampq endpoint" do
      expect(ems.default_endpoint.hostname).to eq "example.org"
      expect(ems.connection_configuration_by_role("amqp").endpoint.hostname).to eq "amqp.example.org"
    end

    it "will contain multiple endpoints" do
      expected_endpoints = ["example.org", "amqp.example.org"]
      expect(ems.hostnames).to match_array(expected_endpoints)
    end
  end

  context "with multiple endpoints using explicit authtype" do
    let(:ems) do
      FactoryBot.build(:ems_openshift,
                        :connection_configurations => [{:endpoint       => {:role     => "default",
                                                                            :hostname => "openshift.example.org"},
                                                        :authentication => {:role     => "bearer",
                                                                            :auth_key => "SomeSecret"}},
                                                       {:endpoint       => {:role     => "hawkular",
                                                                            :hostname => "openshift.example.org"},
                                                        :authentication => {:role     => "hawkular",
                                                                            :auth_key => "SomeSecret"}}])
    end

    it "will contain the bearer authentication as default" do
      expect(ems.connection_configuration_by_role("default").authentication.authtype).to eq("bearer")
    end
    it "will contain the hawkular authentication as hawkular" do
      expect(ems.connection_configuration_by_role("hawkular").authentication.authtype).to eq("hawkular")
    end
  end

  context "with multiple endpoints using implicit default authtype" do
    let(:ems) do
      FactoryBot.build(:ems_openshift,
                        :connection_configurations => [{:endpoint       => {:role     => "default",
                                                                            :hostname => "openshift.example.org"},
                                                        :authentication => {:auth_key => "SomeSecret"}},
                                                       {:endpoint       => {:role     => "hawkular",
                                                                            :hostname => "openshift.example.org"},
                                                        :authentication => {:auth_key => "SomeSecret"}}])
    end

    it "will contain the default authentication (bearer) for default endpoint" do
      expect(ems.connection_configuration_by_role("default").authentication.authtype).to eq("bearer")
    end
    it "will contain the hawkular authentication for the hawkular endpoint" do
      expect(ems.connection_configuration_by_role("hawkular").authentication.authtype).to eq("hawkular")
    end
  end

  context "with two small envs" do
    before do
      @zone1 = FactoryBot.create(:small_environment)
      @zone2 = FactoryBot.create(:small_environment)
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

  describe "refresh" do
    let(:ems) { FactoryBot.create(:ext_management_system) }

    it "raises an error if the authentication check fails" do
      allow(ems).to receive(:missing_credentials?).and_return(false)
      allow(ems).to receive(:authentication_status_ok?).and_return(false)

      expect { ems.refresh }.to raise_error(RuntimeError, "Provider failed last authentication check")
    end

    it "raises an error if no provider credentials are defined" do
      allow(ems).to receive(:authentication_status_ok?).and_return(true)
      allow(ems).to receive(:missing_credentials?).and_return(true)

      expect { ems.refresh }.to raise_error(RuntimeError, "no Provider credentials defined")
    end

    it "calls the EmsRefresh.refresh method internally" do
      allow(ems).to receive(:missing_credentials?).and_return(false)
      allow(ems).to receive(:authentication_status_ok?).and_return(true)
      allow(EmsRefresh).to receive(:refresh)

      ems.refresh

      expect(EmsRefresh).to have_received(:refresh)
    end
  end

  context "with virtual totals" do
    before do
      @ems = FactoryBot.create(:ems_vmware)
      2.times do
        FactoryBot.create(:vm_vmware,
                           :ext_management_system => @ems,
                           :hardware              => FactoryBot.create(:hardware,
                                                                        :cpu1x2,
                                                                        :ram1GB))
      end
      2.times do
        FactoryBot.create(:host,
                           :ext_management_system => @ems,
                           :hardware              => FactoryBot.create(:hardware,
                                                                        :cpu2x2,
                                                                        :ram1GB))
      end
    end

    it "#total_cloud_vcpus" do
      expect(@ems.total_cloud_vcpus).to eq(4)
    end

    it "#total_cloud_memory" do
      expect(@ems.total_cloud_memory).to eq(2048)
    end

    it "#total_vcpus" do
      expect(@ems.total_vcpus).to eq(8)
    end

    it "#total_memory" do
      expect(@ems.total_memory).to eq(2048)
    end

    it "#total_vms_on" do
      expect(@ems.total_vms_on).to eq(2)
    end

    it "#total_vms_off" do
      expect(@ems.total_vms_off).to eq(0)

      @ems.vms.each { |v| v.update(:raw_power_state => "poweredOff") }
      expect(@ems.total_vms_off).to eq(2)
    end

    it "#total_vms_unknown" do
      expect(@ems.total_vms_unknown).to eq(0)

      @ems.vms.each { |v| v.update(:raw_power_state => "unknown") }
      expect(@ems.total_vms_unknown).to eq(2)
    end

    it "#total_vms_never" do
      expect(@ems.total_vms_never).to eq(0)

      @ems.vms.each { |v| v.update(:raw_power_state => "never") }
      expect(@ems.total_vms_never).to eq(2)
    end

    it "#total_vms_suspended" do
      expect(@ems.total_vms_suspended).to eq(0)

      @ems.vms.each { |v| v.update(:raw_power_state => "suspended") }
      expect(@ems.total_vms_suspended).to eq(2)
    end

    %w(total_vms_on total_vms_off total_vms_unknown total_vms_never total_vms_suspended).each do |vcol|
      it "should have virtual column #{vcol} " do
        expect(described_class).to have_virtual_column vcol.to_s, :integer
      end
    end

    it "#total_vms" do
      expect(@ems.total_vms).to eq(2)
    end

    it "#total_vms_and_templates" do
      FactoryBot.create(:template_vmware, :ext_management_system => @ems)
      expect(@ems.total_vms_and_templates).to eq(3)
    end

    it "#total_miq_templates" do
      FactoryBot.create(:template_vmware, :ext_management_system => @ems)
      expect(@ems.total_miq_templates).to eq(1)
    end
  end

  describe "#total_clusters" do
    it "knows it has none" do
      ems = FactoryBot.create(:ems_vmware)
      expect(ems.total_clusters).to eq(0)
    end

    it "knows it has one" do
      ems = FactoryBot.create(:ems_vmware)
      FactoryBot.create(:ems_cluster, :ext_management_system => ems)
      expect(ems.total_clusters).to eq(1)
    end
  end

  context "validates" do
    context "across tenants" do
      before do
        tenant1  = Tenant.seed
        @tenant2 = FactoryBot.create(:tenant, :parent => tenant1)
        @ems     = FactoryBot.create(:ems_vmware, :tenant => tenant1)
      end

      it "allowing duplicate name" do
        expect do
          FactoryBot.create(:ems_vmware, :name => @ems.name, :tenant => @tenant2)
        end.to_not raise_error
      end

      it "not allowing duplicate hostname for same type provider" do
        expect do
          FactoryBot.create(:ems_vmware, :hostname => @ems.hostname, :tenant => @tenant2)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "allowing duplicate hostname for different type providers" do
        FactoryBot.create(:ems_microsoft, :hostname => @ems.hostname, :tenant => @tenant2)
        expect(ExtManagementSystem.count).to eq(2)
      end
    end
  end

  context "#tenant" do
    let(:tenant) { FactoryBot.create(:tenant) }
    it "has a tenant" do
      ems = FactoryBot.create(:ext_management_system, :tenant => tenant)
      expect(tenant.ext_management_systems).to include(ems)
    end
  end

  context "#pause!" do
    before do
      MiqRegion.seed
      Zone.seed
    end

    it 'disables an ems with child managers and moves them to maintenance zone' do
      zone  = FactoryGirl.create(:zone)
      ems   = FactoryGirl.create(:ext_management_system, :zone => zone)
      child = FactoryGirl.create(:ext_management_system, :zone => zone)
      ems.child_managers << child

      2.times do
        ems.pause!

        expect(ems.enabled).to eq(false)
        expect(ems.zone).to eq(Zone.maintenance_zone)
        expect(ems.zone_before_pause).to eq(zone)

        child.reload
        expect(child.enabled).to eq(false)
        expect(child.zone).to eq(Zone.maintenance_zone)
        expect(child.zone_before_pause).to eq(zone)
      end
    end

    it 'disables an ems and moves child managers created by ensure_managers() to maintenance zone' do
      zone  = FactoryGirl.create(:zone)
      emses = {
        :amazon_cloud    => FactoryGirl.create(:ems_amazon,          :zone => zone),
        :azure_cloud     => FactoryGirl.create(:ems_azure,           :zone => zone),
        :google_cloud    => FactoryGirl.create(:ems_google,          :zone => zone),
        :openstack_cloud => FactoryGirl.create(:ems_openstack,       :zone => zone),
        :openstack_infra => FactoryGirl.create(:ems_openstack_infra, :zone => zone),
        :vmware_cloud    => FactoryGirl.create(:ems_vmware_cloud,    :zone => zone),
      }

      2.times do
        # managers with child managers created with ensure_managers() callback has own callback to change zone
        # so it should be tested separately
        emses.each_value do |manager|
          manager.pause!

          manager.reload
          expect(manager.network_manager.zone_before_pause).to eq(zone)
          expect(manager.network_manager.zone).to eq(Zone.maintenance_zone)
        end

        # The same for storage managers, i.e. amazon
        %i[amazon_cloud openstack_cloud].each do |manager_type|
          emses[manager_type].storage_managers.each do |storage_manager|
            expect(storage_manager.zone_before_pause).to eq(zone)
            expect(storage_manager.zone).to eq(Zone.maintenance_zone)
          end
        end
      end
    end
  end

  context "#resume" do
    before do
      MiqRegion.seed
      Zone.seed
    end

    it "enables an ems with child managers and move them from maintenance zone" do
      zone = FactoryGirl.create(:zone)
      ems = FactoryGirl.create(:ext_management_system,
                               :zone_before_pause => zone,
                               :zone              => Zone.maintenance_zone,
                               :enabled           => false)

      child = FactoryGirl.create(:ext_management_system,
                                 :zone_before_pause => zone,
                                 :zone              => Zone.maintenance_zone,
                                 :enabled           => false)
      ems.child_managers << child

      ems.resume!

      expect(ems.enabled).to eq(true)
      expect(ems.zone).to eq(zone)
      expect(ems.zone_before_pause).to be_nil

      child.reload
      expect(child.enabled).to eq(true)
      expect(child.zone).to eq(zone)
      expect(child.zone_before_pause).to be_nil
    end

    it "doesn't change zone when ems was disabled before" do
      zone = FactoryGirl.create(:zone)
      ems = FactoryGirl.create(:ext_management_system,
                               :zone_before_pause => nil,
                               :zone              => zone,
                               :enabled           => false)

      ems.resume!

      expect(ems.enabled).to eq(true)
      expect(ems.zone).to eq(zone)
    end

    it 'enables an ems and moves child managers created by ensure_managers() to original zone' do
      zone  = FactoryGirl.create(:zone)
      # Cannot create paused child managers this way, so we first pause! (tested yet) and then resume!
      emses = {
        :amazon_cloud    => FactoryGirl.create(:ems_amazon,          :zone => zone),
        :azure_cloud     => FactoryGirl.create(:ems_azure,           :zone => zone),
        :google_cloud    => FactoryGirl.create(:ems_google,          :zone => zone),
        :openstack_cloud => FactoryGirl.create(:ems_openstack,       :zone => zone),
        :openstack_infra => FactoryGirl.create(:ems_openstack_infra, :zone => zone),
        :vmware_cloud    => FactoryGirl.create(:ems_vmware_cloud,    :zone => zone),
      }

      # managers with child managers created with ensure_managers() callback has own callback to change zone
      # so it should be tested separately
      emses.each_value do |manager|
        manager.pause!
        manager.reload

        manager.resume!
        manager.reload

        expect(manager.network_manager.zone_before_pause).to be_nil
        expect(manager.network_manager.zone).to eq(zone)
      end

      # The same for storage managers, i.e. amazon
      %i(amazon_cloud openstack_cloud).each do |manager_type|
        emses[manager_type].storage_managers.each do |storage_manager|
          expect(storage_manager.zone_before_pause).to be_nil
          expect(storage_manager.zone).to eq(zone)
        end
      end
    end
  end

  context "changing zone" do
    before do
      MiqRegion.seed
      Zone.seed
    end

    it 'is allowed when enabled' do
      zone = FactoryGirl.create(:zone)
      ems  = FactoryGirl.create(:ext_management_system, :zone => Zone.default_zone)

      ems.zone = zone
      expect(ems.save).to eq(true)
    end

    it 'is denied when disabled' do
      zone = FactoryGirl.create(:zone)
      ems  = FactoryGirl.create(:ext_management_system, :zone => Zone.default_zone, :enabled => false)

      ems.zone = zone
      expect(ems.save).to eq(false)
      expect(ems.errors.messages[:zone]).to be_present
    end

    it 'to maintenance is not possible when provider enabled' do
      zone_visible = FactoryGirl.create(:zone)

      ems = FactoryGirl.create(:ext_management_system, :zone => zone_visible, :enabled => true)

      ems.zone = Zone.maintenance_zone
      expect(ems.save).to eq(false)
      expect(ems.errors.messages[:zone]).to be_present
    end
  end

  context "destroy" do
    it "destroys an ems with no active workers" do
      ems = FactoryBot.create(:ext_management_system)
      ems.destroy
      expect(ExtManagementSystem.count).to eq(0)
    end

    it "destroys an ems with active workers" do
      ems = FactoryBot.create(:ext_management_system)
      worker = FactoryBot.create(:miq_ems_refresh_worker, :queue_name => ems.queue_name, :status => "started", :miq_server => EvmSpecHelper.local_miq_server)

      ems.destroy

      # Simulate another process delivering the worker kill message
      queue_message = MiqQueue.order(:id).first
      status, message, result = queue_message.deliver
      queue_message.delivered(status, message, result)

      expect(ExtManagementSystem.count).to eq(0)
      expect(worker.class.exists?(worker.id)).to eq(false)
    end
  end

  context ".destroy_queue" do
    let(:ems)    { FactoryBot.create(:ext_management_system, :zone => zone) }
    let(:ems2)   { FactoryBot.create(:ext_management_system, :zone => zone) }
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:zone)   { server.zone }

    it "queues up destroy" do
      described_class.destroy_queue([ems.id, ems2.id])

      expect(MiqQueue.count).to eq(2)
      expect(MiqQueue.pluck(:instance_id)).to match_array([ems.id, ems2.id])
    end
  end

  context "#destroy_queue" do
    let(:ems)    { FactoryBot.create(:ext_management_system, :zone => zone) }
    let(:server) { EvmSpecHelper.local_miq_server }
    let(:zone)   { server.zone }

    it "returns a task" do
      task_id = ems.destroy_queue

      deliver_queue_message

      expect(MiqTask.find(task_id)).to have_attributes(
        :state  => "Finished",
        :status => "Ok",
      )
    end

    it "destroys the ems when no active worker exists" do
      ems.destroy_queue

      expect(MiqQueue.count).to eq(1)

      deliver_queue_message

      expect(MiqQueue.count).to eq(0)
      expect(ExtManagementSystem.count).to eq(0)
    end

    it "destroys the ems when active worker exists" do
      FactoryBot.create(:miq_ems_refresh_worker, :queue_name => ems.queue_name, :status => "started", :miq_server => server)
      ems.destroy_queue

      expect(MiqQueue.count).to eq(1)
      deliver_queue_message #  ems destroy message
      deliver_queue_message #  worker kill message

      expect(MiqQueue.count).to eq(0)
      expect(ExtManagementSystem.count).to eq(0)
      expect(MiqWorker.count).to eq(0)
    end

    def deliver_queue_message(queue_message = MiqQueue.order(:id).first)
      status, message, result = queue_message.deliver
      queue_message.delivered(status, message, result)
    end
  end

  describe ".create_from_params" do
    let(:zone)   { EvmSpecHelper.create_guid_miq_server_zone.last }
    let(:params) { {"name" => "My Provider", "zone_id" => zone.id.to_s, "type" => "ManageIQ::Providers::Amazon::CloudManager", "provider_region" => "us-east-1"} }
    let(:endpoints) { [{"role" => "default"}] }

    context "with a userid/password type authentication" do
      let(:authentications) { [{"authtype" => "default", "userid" => "user", "password" => "password"}] }

      it "creates an AuthUseridPassword type authentication record" do
        ems = described_class.create_from_params(params, endpoints, authentications)
        expect(ems.authentications.first.class.name).to eq("AuthUseridPassword")
      end

      it "queues an initial authentication check" do
        described_class.create_from_params(params, endpoints, authentications)
        expect(MiqQueue.pluck(:class_name, :method_name)).to include(["ExtManagementSystem", "authentication_check_types"])
      end
    end

    context "with an auth_token type authentication" do
      let(:authentications) { [{"authtype" => "default", "auth_key" => "abcdefg"}] }

      it "creates an AuthToken type authentication record" do
        ems = described_class.create_from_params(params, endpoints, authentications)
        expect(ems.authentications.first.class.name).to eq("AuthToken")
      end

      it "queues an initial authentication check" do
        described_class.create_from_params(params, endpoints, authentications)
        expect(MiqQueue.pluck(:class_name, :method_name)).to include(["ExtManagementSystem", "authentication_check_types"])
      end
    end
  end

  context "virtual column :supports_block_storage" do
    it "returns true if block storage is supported" do
      ems = FactoryBot.create(:ext_management_system)
      allow(ems).to receive(:supports_block_storage).and_return(true)
      expect(ems.supports_block_storage).to eq(true)
    end
  end

  context "virtual column :supports_cloud_object_store_container_create" do
    it "returns true if cloud_object_store_container_create is supported" do
      ems = FactoryBot.create(:ext_management_system)
      allow(ems).to receive(:supports_cloud_object_store_container_create).and_return(true)
      expect(ems.supports_cloud_object_store_container_create).to eq(true)
    end
  end

  describe ".raw_connect?" do
    it "returns true if validation was successful" do
      allow(described_class).to receive(:raw_connect).and_return(double)
      expect(described_class.raw_connect?).to eq(true)
    end
  end

  context "raw_connect" do
    it 'defines a raw_connect method which raises an error' do
      expect(described_class).to respond_to(:raw_connect)
      expect { described_class.raw_connect }.to raise_error(NotImplementedError, _("must be implemented in a subclass"))
    end
  end

  describe ".inventory_status" do
    it "works with infra providers" do
      ems = FactoryBot.create(:ems_infra)
      host = FactoryBot.create(:host, :ext_management_system => ems)
      FactoryBot.create(:vm_infra, :ext_management_system => ems, :host => host)
      FactoryBot.create(:vm_infra, :ext_management_system => ems, :host => host)

      result = ExtManagementSystem.inventory_status
      expect(result.size).to eq(2)
      expect(result[0]).to eq(%w(region zone kind ems hosts vms))
      expect(result[1][4..-1]).to eq([1, 2])
    end

    it "works with container providers" do
      ems = FactoryBot.create(:ems_container)
      FactoryBot.create(:container, :ems_id => ems.id)
      FactoryBot.create(:container, :ems_id => ems.id)
      result = ExtManagementSystem.inventory_status
      expect(result.size).to eq(2)
      expect(result[0]).to eq(%w(region zone kind ems containers))
      expect(result[1][4..-1]).to eq([2])
    end
  end

  context "#queue_name_for_ems_operations" do
    it "defaults to 'generic' as the queue name for ems operations" do
      ems_cloud = FactoryBot.create(:ems_cloud)
      ems_container = FactoryBot.create(:ems_container)

      expect(ems_cloud.queue_name_for_ems_operations).to eql('generic')
      expect(ems_container.queue_name_for_ems_operations).to eql('generic')
    end
  end
end
