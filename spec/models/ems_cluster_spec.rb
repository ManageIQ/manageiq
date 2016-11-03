describe EmsCluster do
  context("VMware") do
    before(:each) do
      @cluster = FactoryGirl.create(:ems_cluster)
      @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @rp1 = FactoryGirl.create(:resource_pool)
      @rp2 = FactoryGirl.create(:resource_pool)

      @cluster.with_relationship_type("ems_metadata") { @cluster.add_child @rp1 }
      @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

      @vm1 = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_cluster => @cluster)
      @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }
      @template1 = FactoryGirl.create(:template_vmware, :host => @host1, :ems_cluster => @cluster)

      @vm2 = FactoryGirl.create(:vm_vmware, :host => @host2, :ems_cluster => @cluster)
      @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }
      @template2 = FactoryGirl.create(:template_vmware, :host => @host2, :ems_cluster => @cluster)
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

    it('#all_vms_and_templates')   { expect(@cluster.all_vms_and_templates).to   match_array [@vm1, @vm2, @template1, @template2] }
    it('#all_vm_or_template_ids')  { expect(@cluster.all_vm_or_template_ids).to  match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#total_vms_and_templates') { expect(@cluster.total_vms_and_templates).to eq(4) }

    it('#all_vms')    { expect(@cluster.all_vms).to    match_array [@vm1, @vm2] }
    it('#all_vm_ids') { expect(@cluster.all_vm_ids).to match_array [@vm1.id, @vm2.id] }
    it('#total_vms')  { expect(@cluster.total_vms).to eq(2) }

    it('#all_miq_templates')    { expect(@cluster.all_miq_templates).to    match_array [@template1, @template2] }
    it('#all_miq_template_ids') { expect(@cluster.all_miq_template_ids).to match_array [@template1.id, @template2.id] }
    it('#total_miq_templates')  { expect(@cluster.total_miq_templates).to eq(2) }

    it('ResourcePool#v_direct_vms') { expect(@rp1.v_direct_vms).to eq(1) }
    it('ResourcePool#v_total_vms')  { expect(@rp1.v_total_vms).to eq(2) }

    it('ResourcePool#v_direct_miq_templates') { expect(@rp1.v_direct_vms).to eq(1) }
    it('ResourcePool#v_total_miq_templates')  { expect(@rp1.v_total_vms).to eq(2) }
    it('#hosts') { expect(@cluster.hosts).to match_array [@host1, @host2] }
    it('#all_hosts') { expect(@cluster.all_hosts).to match_array [@host1, @host2] }
    it('#total_hosts') { expect(@cluster.total_hosts).to eq(2) }
  end

  context("RedHat") do
    before(:each) do
      @cluster = FactoryGirl.create(:ems_cluster)
      @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @rp1 = FactoryGirl.create(:resource_pool)
      @rp2 = FactoryGirl.create(:resource_pool)

      @cluster.with_relationship_type("ems_metadata") { @cluster.add_child @rp1 }
      @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

      @vm1 = FactoryGirl.create(:vm_redhat, :host => @host1, :ems_cluster => @cluster)
      @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }

      @vm2 = FactoryGirl.create(:vm_redhat, :host => @host2, :ems_cluster => @cluster)
      @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }

      @template1 = FactoryGirl.create(:template_redhat, :ems_cluster => @cluster)
      @template2 = FactoryGirl.create(:template_redhat, :ems_cluster => @cluster)
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

    it('#all_vms_and_templates')   { expect(@cluster.all_vms_and_templates).to   match_array [@vm1, @vm2, @template1, @template2] }
    it('#all_vm_or_template_ids')  { expect(@cluster.all_vm_or_template_ids).to  match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#total_vms_and_templates') { expect(@cluster.total_vms_and_templates).to eq(4) }

    it('#all_vms')    { expect(@cluster.all_vms).to    match_array [@vm1, @vm2] }
    it('#all_vm_ids') { expect(@cluster.all_vm_ids).to match_array [@vm1.id, @vm2.id] }
    it('#total_vms')  { expect(@cluster.total_vms).to eq(2) }

    it('#all_miq_templates')    { expect(@cluster.all_miq_templates).to    match_array [@template1, @template2] }
    it('#all_miq_template_ids') { expect(@cluster.all_miq_template_ids).to match_array [@template1.id, @template2.id] }
    it('#total_miq_templates')  { expect(@cluster.total_miq_templates).to eq(2) }
    it('#hosts')                { expect(@cluster.hosts).to match_array [@host1, @host2] }
    it('#all_hosts')            { expect(@cluster.all_hosts).to match_array [@host1, @host2] }
    it('#total_hosts')          { expect(@cluster.total_hosts).to eq(2) }
  end

  it "#save_drift_state" do
    # TODO: Beef up with more data
    cluster = FactoryGirl.create(:ems_cluster)
    cluster.save_drift_state

    expect(cluster.drift_states.size).to eq(1)
    expect(DriftState.count).to eq(1)

    expect(cluster.drift_states.first.data).to eq({
      :aggregate_cpu_speed       => 0,
      :aggregate_cpu_total_cores => 0,
      :aggregate_memory          => 0,
      :aggregate_physical_cpus   => 0,
      :aggregate_vm_cpus         => 0,
      :aggregate_vm_memory       => 0,
      :class                     => "EmsCluster",
      :id                        => cluster.id,
      :name                      => cluster.name,
      :vms                       => [],
      :miq_templates             => [],
      :hosts                     => [],
    })
  end

  context("#perf_capture_enabled_host_ids=") do
    before do
      @miq_region = FactoryGirl.create(:miq_region, :region => 1)
      allow(MiqRegion).to receive(:my_region).and_return(@miq_region)
      @cluster = FactoryGirl.create(:ems_cluster)
      @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryGirl.create(:host, :ems_cluster => @cluster)
    end

    it "Initially Performance capture for cluster and its hosts should not be set" do
      expect(@cluster.perf_capture_enabled).to eq(false)
      expect(@host1.perf_capture_enabled).to eq(false)
      expect(@host2.perf_capture_enabled).to eq(false)
    end

    it "Performance capture for cluster and its hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host1.id, @host2.id]
      expect(@cluster.perf_capture_enabled).to eq(true)
      expect(@host1.perf_capture_enabled).to eq(true)
      expect(@host2.perf_capture_enabled).to eq(true)
    end

    it "Performance capture for cluster and only 1 hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      expect(@cluster.perf_capture_enabled).to eq(true)
      expect(@host1.perf_capture_enabled).to eq(false)
      expect(@host2.perf_capture_enabled).to eq(true)
    end

    it "Performance capture for cluster and its hosts should get unset" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      @cluster.perf_capture_enabled_host_ids = []
      expect(@cluster.perf_capture_enabled).to eq(false)
      expect(@host1.perf_capture_enabled).to eq(false)
      expect(@host2.perf_capture_enabled).to eq(false)
    end
  end

  context "#node_types" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns :mixed_clusters when there are both openstack & non-openstack clusters in db" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = EmsCluster.node_types
      expect(result).to eq(:mixed_clusters)
    end

    it "returns :openstack when there are only openstack clusters in db" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)
      result = EmsCluster.node_types
      expect(result).to eq(:openstack)
    end

    it "returns :non_openstack when there are non-openstack clusters in db" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)
      result = EmsCluster.node_types
      expect(result).to eq(:non_openstack)
    end
  end

  context "#openstack_cluster?" do
    it "returns true for openstack cluster" do
      ems = FactoryGirl.create(:ems_openstack_infra)
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => ems.id)

      result = cluster.openstack_cluster?
      expect(result).to be_truthy
    end

    it "returns false for non-openstack cluster" do
      ems = FactoryGirl.create(:ems_vmware)
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => ems.id)
      result = cluster.openstack_cluster?
      expect(result).to be_falsey
    end
  end

  context "#tenant_identity" do
    let(:admin)    { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryGirl.create(:tenant) }
    let(:ems)      { FactoryGirl.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @cluster.tenant_identity }

    it "has tenant from provider" do
      @cluster = FactoryGirl.create(:ems_cluster, :ems_id => ems.id)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @cluster = FactoryGirl.create(:ems_cluster)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end
end
