RSpec.describe EmsCluster do
  subject { FactoryBot.create(:ems_cluster) }

  include_examples "AggregationMixin"
  include_examples "MiqPolicyMixin"

  context("VMware") do
    before do
      @cluster = FactoryBot.create(:ems_cluster)
      @host1 = FactoryBot.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryBot.create(:host, :ems_cluster => @cluster)
      @rp1 = FactoryBot.create(:resource_pool)
      @rp2 = FactoryBot.create(:resource_pool)

      @cluster.with_relationship_type("ems_metadata") { @cluster.add_child @rp1 }
      @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

      @vm1 = FactoryBot.create(:vm_vmware, :host => @host1, :ems_cluster => @cluster)
      @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }
      @template1 = FactoryBot.create(:template_vmware, :host => @host1, :ems_cluster => @cluster)

      @vm2 = FactoryBot.create(:vm_vmware, :host => @host2, :ems_cluster => @cluster)
      @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }
      @template2 = FactoryBot.create(:template_vmware, :host => @host2, :ems_cluster => @cluster)
    end

    it('#vms_and_templates')              { expect(@cluster.vms_and_templates).to              match_array [@vm1, @vm2, @template1, @template2] }
    it('#direct_vms_and_templates')       { expect(@cluster.direct_vms_and_templates).to       match_array [@vm1, @template1, @template2] }
    it('#vm_or_template_ids')             { expect(@cluster.vm_or_template_ids).to             match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#direct_vm_or_template_ids')      { expect(@cluster.direct_vm_or_template_ids).to      match_array [@vm1.id, @template1.id, @template2.id] }
    it('#total_direct_vms_and_templates') { expect(@cluster.total_direct_vms_and_templates).to eq(3) }

    it('#vms')              { expect(@cluster.vms).to              match_array [@vm1, @vm2] }
    it('#direct_vms')       { expect(@cluster.direct_vms).to       match_array [@vm1] }
    it('#vm_ids')           { expect(@cluster.vm_ids).to           match_array [@vm1.id, @vm2.id] }
    it('#direct_vm_ids')    { expect(@cluster.direct_vm_ids).to    match_array [@vm1.id] }
    it('#total_direct_vms') { expect(@cluster.total_direct_vms).to eq(1) }

    it('#miq_templates')              { expect(@cluster.miq_templates).to              match_array [@template1, @template2] }
    it('#direct_miq_templates')       { expect(@cluster.direct_miq_templates).to       match_array [@template1, @template2] }
    it('#miq_template_ids')           { expect(@cluster.miq_template_ids).to           match_array [@template1.id, @template2.id] }
    it('#direct_miq_template_ids')    { expect(@cluster.direct_miq_template_ids).to    match_array [@template1.id, @template2.id] }
    it('#total_direct_miq_templates') { expect(@cluster.total_direct_miq_templates).to eq(2) }

    it('#total_vms_and_templates') { expect(@cluster.total_vms_and_templates).to eq(4) }

    it('#total_vms')  { expect(@cluster.total_vms).to eq(2) }

    it('#total_miq_templates')  { expect(@cluster.total_miq_templates).to eq(2) }

    it('ResourcePool#v_direct_vms') { expect(@rp1.v_direct_vms).to eq(1) }
    it('ResourcePool#v_total_vms')  { expect(@rp1.v_total_vms).to eq(2) }

    it('ResourcePool#v_direct_miq_templates') { expect(@rp1.v_direct_vms).to eq(1) }
    it('ResourcePool#v_total_miq_templates')  { expect(@rp1.v_total_vms).to eq(2) }
    it('#hosts') { expect(@cluster.hosts).to match_array [@host1, @host2] }
    it('#total_hosts') { expect(@cluster.total_hosts).to eq(2) }
  end

  context("RedHat") do
    before do
      @cluster = FactoryBot.create(:ems_cluster)
      @host1 = FactoryBot.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryBot.create(:host, :ems_cluster => @cluster)
      @rp1 = FactoryBot.create(:resource_pool)
      @rp2 = FactoryBot.create(:resource_pool)

      @cluster.with_relationship_type("ems_metadata") { @cluster.add_child @rp1 }
      @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

      @vm1 = FactoryBot.create(:vm_redhat, :host => @host1, :ems_cluster => @cluster)
      @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }

      @vm2 = FactoryBot.create(:vm_redhat, :host => @host2, :ems_cluster => @cluster)
      @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }

      @template1 = FactoryBot.create(:template_redhat, :ems_cluster => @cluster)
      @template2 = FactoryBot.create(:template_redhat, :ems_cluster => @cluster)
    end

    it('#vms_and_templates')              { expect(@cluster.vms_and_templates).to              match_array [@vm1, @vm2, @template1, @template2] }
    it('#direct_vms_and_templates')       { expect(@cluster.direct_vms_and_templates).to       match_array [@vm1, @template1, @template2] }
    it('#vm_or_template_ids')             { expect(@cluster.vm_or_template_ids).to             match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#direct_vm_or_template_ids')      { expect(@cluster.direct_vm_or_template_ids).to      match_array [@vm1.id, @template1.id, @template2.id] }
    it('#total_direct_vms_and_templates') { expect(@cluster.total_direct_vms_and_templates).to eq(3) }

    it('#vms')              { expect(@cluster.vms).to              match_array [@vm1, @vm2] }
    it('#direct_vms')       { expect(@cluster.direct_vms).to       match_array [@vm1] }
    it('#vm_ids')           { expect(@cluster.vm_ids).to           match_array [@vm1.id, @vm2.id] }
    it('#direct_vm_ids')    { expect(@cluster.direct_vm_ids).to    match_array [@vm1.id] }
    it('#total_direct_vms') { expect(@cluster.total_direct_vms).to eq(1) }

    it('#miq_templates')              { expect(@cluster.miq_templates).to              match_array [@template1, @template2] }
    it('#direct_miq_templates')       { expect(@cluster.direct_miq_templates).to       match_array [@template1, @template2] }
    it('#miq_template_ids')           { expect(@cluster.miq_template_ids).to           match_array [@template1.id, @template2.id] }
    it('#direct_miq_template_ids')    { expect(@cluster.direct_miq_template_ids).to    match_array [@template1.id, @template2.id] }
    it('#total_direct_miq_templates') { expect(@cluster.total_direct_miq_templates).to eq(2) }

    it('#total_vms_and_templates') { expect(@cluster.total_vms_and_templates).to eq(4) }

    it('#total_vms')  { expect(@cluster.total_vms).to eq(2) }

    it('#total_miq_templates')  { expect(@cluster.total_miq_templates).to eq(2) }
    it('#hosts')                { expect(@cluster.hosts).to match_array [@host1, @host2] }
    it('#total_hosts')          { expect(@cluster.total_hosts).to eq(2) }
  end

  context("#save_drift_state") do
    it "without aggregate data" do
      # TODO: Beef up with more data
      cluster = FactoryBot.create(:ems_cluster)
      cluster.save_drift_state

      expect(cluster.drift_states.size).to eq(1)
      expect(DriftState.count).to eq(1)

      expect(cluster.drift_states.first.data).to eq(
        :class         => "EmsCluster",
        :id            => cluster.id,
        :name          => cluster.name,
        :vms           => [],
        :miq_templates => [],
        :hosts         => []
      )
    end

    it "with aggregate data" do
      cluster = FactoryBot.create(:ems_cluster)
      host = FactoryBot.create(:host,
                               :ems_cluster           => cluster,
                               :ext_management_system => FactoryBot.create(:ext_management_system),
                               :hardware              => FactoryBot.build(:hardware,
                                                                          :cpu_total_cores => 4,
                                                                          :cpu_speed       => 1000,
                                                                          :memory_mb       => 2_048))

      vm = FactoryBot.create(:vm_redhat, :host => host, :ems_cluster => cluster)

      cluster.save_drift_state

      expect(cluster.drift_states.size).to eq(1)
      expect(DriftState.count).to eq(1)
      expect(cluster.drift_states.first.data).to eq(
        :aggregate_cpu_speed       => 4000,
        :aggregate_cpu_total_cores => 4,
        :aggregate_memory          => 2048,
        :aggregate_physical_cpus   => 1,
        :class                     => "EmsCluster",
        :id                        => cluster.id,
        :name                      => cluster.name,
        :vms                       => [{:class => "ManageIQ::Providers::Redhat::InfraManager::Vm", :id => vm.id}],
        :miq_templates             => [],
        :hosts                     => [{:class => "Host", :id => host.id}]
      )
    end
  end

  context("#perf_capture_enabled_host_ids=") do
    before do
      @miq_region = FactoryBot.create(:miq_region, :region => 1)
      allow(MiqRegion).to receive(:my_region).and_return(@miq_region)
      @cluster = FactoryBot.create(:ems_cluster)
      @host1 = FactoryBot.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryBot.create(:host, :ems_cluster => @cluster)
    end

    it "Initially Performance capture for cluster and its hosts should not be set" do
      expect(@cluster.perf_capture_enabled?).to eq(false)
      expect(@host1.perf_capture_enabled?).to eq(false)
      expect(@host2.perf_capture_enabled?).to eq(false)
    end

    it "Performance capture for cluster and its hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host1.id, @host2.id]
      expect(@cluster.perf_capture_enabled?).to eq(true)
      expect(@host1.perf_capture_enabled?).to eq(true)
      expect(@host2.perf_capture_enabled?).to eq(true)
    end

    it "Performance capture for cluster and only 1 hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      expect(@cluster.perf_capture_enabled?).to eq(true)
      expect(@host1.perf_capture_enabled?).to eq(false)
      expect(@host2.perf_capture_enabled?).to eq(true)
    end

    it "Performance capture for cluster and its hosts should get unset" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      @cluster.perf_capture_enabled_host_ids = []
      expect(@cluster.perf_capture_enabled?).to eq(false)
      expect(@host1.perf_capture_enabled?).to eq(false)
      expect(@host2.perf_capture_enabled?).to eq(false)
    end
  end

  context "#tenant_identity" do
    let(:admin)    { FactoryBot.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryBot.create(:tenant) }
    let(:ems)      { FactoryBot.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @cluster.tenant_identity }

    it "has tenant from provider" do
      @cluster = FactoryBot.create(:ems_cluster, :ems_id => ems.id)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @cluster = FactoryBot.create(:ems_cluster)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end

  context "#upgrade_cluster" do
    before do
      @ems = FactoryBot.create(:ems_redhat_with_authentication_with_ca, :skip_validate)
      @cluster = FactoryBot.create(:ems_cluster_ovirt, :ems_id => @ems.id)
      my_server = double("my_server", :guid => "guid1")
      allow(MiqServer).to receive(:my_server).and_return(my_server)
    end

    it "sends the right parameters to the upgrade" do
      env_vars = {}
      extra_args = {:engine_url      => "https://#{@ems.address}/ovirt-engine/api",
                    :engine_user     => @ems.authentication_userid,
                    :engine_password => @ems.authentication_password,
                    :cluster_name    => @cluster.name,
                    :hostname        => "localhost",
                    :ca_string       => @ems.default_endpoint.certificate_authority}
      role_arg = { :role_name => "oVirt.cluster-upgrade" }
      timeout = { :timeout => 1.year }
      expect(ManageIQ::Providers::AnsibleRoleWorkflow).to receive(:create_job).with(env_vars, extra_args, role_arg, timeout).and_call_original
      @cluster.upgrade_cluster
    end

    it 'supports upgrade_cluster when provider is rhv' do
      expect(@cluster.supports_upgrade_cluster?).to be_truthy
    end

    context "non rhv cluster" do
      before do
        @cluster = FactoryBot.create(:ems_cluster)
      end

      it 'does not support upgrade_cluster' do
        expect(@cluster.supports_upgrade_cluster?).to be_falsey
      end
    end
  end

  describe "#event_where_clause" do
    let(:cluster) { FactoryBot.create(:ems_cluster) }
    # just doing one to avoid db random ordering
    let(:vms) { FactoryBot.create_list(:vm, 1, :ems_cluster => cluster)}
    let(:hosts) { FactoryBot.create_list(:host, 1, :ems_cluster => cluster)}
    it "handles empty cluster" do
      expect(cluster.event_where_clause).to eq(["ems_cluster_id = ?", cluster.id])
    end

    it "handles vms" do
      vms # pre-load vms
      result = cluster.event_where_clause
      expected = [
        "ems_cluster_id = ? OR vm_or_template_id IN (?) OR dest_vm_or_template_id IN (?)",
        cluster.id, vms.map(&:id), vms.map(&:id)
      ]
      expect(result).to eq(expected)
    end

    it "handles hosts" do
      hosts # pre-load vms
      result = cluster.event_where_clause
      expected = [
        "ems_cluster_id = ? OR host_id IN (?) OR dest_host_id IN (?)",
        cluster.id, hosts.map(&:id), hosts.map(&:id)
      ]
      expect(result).to eq(expected)
    end

    it "handles both" do
      vms # pre-load vms, hosts
      hosts
      result = cluster.event_where_clause
      expected = [
        "ems_cluster_id = ? OR host_id IN (?) OR dest_host_id IN (?) OR vm_or_template_id IN (?) OR dest_vm_or_template_id IN (?)",
        cluster.id, hosts.map(&:id), hosts.map(&:id), vms.map(&:id), vms.map(&:id)
      ]
      expect(result).to eq(expected)
    end
  end
end
