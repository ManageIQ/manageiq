require "spec_helper"

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

    it('#vms_and_templates')              { @cluster.vms_and_templates.should              match_array [@vm1, @vm2, @template1, @template2] }
    it('#direct_vms_and_templates')       { @cluster.direct_vms_and_templates.should       match_array [@vm1, @template1, @template2] }
    it('#vm_or_template_ids')             { @cluster.vm_or_template_ids.should             match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#direct_vm_or_template_ids')      { @cluster.direct_vm_or_template_ids.should      match_array [@vm1.id, @template1.id, @template2.id] }
    it('#total_direct_vms_and_templates') { @cluster.total_direct_vms_and_templates.should == 3 }

    it('#vms')              { @cluster.vms.should              match_array [@vm1, @vm2] }
    it('#direct_vms')       { @cluster.direct_vms.should       match_array [@vm1] }
    it('#vm_ids')           { @cluster.vm_ids.should           match_array [@vm1.id, @vm2.id] }
    it('#direct_vm_ids')    { @cluster.direct_vm_ids.should    match_array [@vm1.id] }
    it('#total_direct_vms') { @cluster.total_direct_vms.should == 1 }

    it('#miq_templates')              { @cluster.miq_templates.should              match_array [@template1, @template2] }
    it('#direct_miq_templates')       { @cluster.direct_miq_templates.should       match_array [@template1, @template2] }
    it('#miq_template_ids')           { @cluster.miq_template_ids.should           match_array [@template1.id, @template2.id] }
    it('#direct_miq_template_ids')    { @cluster.direct_miq_template_ids.should    match_array [@template1.id, @template2.id] }
    it('#total_direct_miq_templates') { @cluster.total_direct_miq_templates.should == 2 }

    it('#all_vms_and_templates')   { @cluster.all_vms_and_templates.should   match_array [@vm1, @vm2, @template1, @template2] }
    it('#all_vm_or_template_ids')  { @cluster.all_vm_or_template_ids.should  match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#total_vms_and_templates') { @cluster.total_vms_and_templates.should == 4 }

    it('#all_vms')    { @cluster.all_vms.should    match_array [@vm1, @vm2] }
    it('#all_vm_ids') { @cluster.all_vm_ids.should match_array [@vm1.id, @vm2.id] }
    it('#total_vms')  { @cluster.total_vms.should  == 2 }

    it('#all_miq_templates')    { @cluster.all_miq_templates.should    match_array [@template1, @template2] }
    it('#all_miq_template_ids') { @cluster.all_miq_template_ids.should match_array [@template1.id, @template2.id] }
    it('#total_miq_templates')  { @cluster.total_miq_templates.should  == 2 }

    it('ResourcePool#v_direct_vms') { @rp1.v_direct_vms.should == 1 }
    it('ResourcePool#v_total_vms')  { @rp1.v_total_vms.should  == 2 }

    it('ResourcePool#v_direct_miq_templates') { @rp1.v_direct_vms.should == 1 }
    it('ResourcePool#v_total_miq_templates')  { @rp1.v_total_vms.should  == 2 }
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

    it('#vms_and_templates')              { @cluster.vms_and_templates.should              match_array [@vm1, @vm2, @template1, @template2] }
    it('#direct_vms_and_templates')       { @cluster.direct_vms_and_templates.should       match_array [@vm1, @template1, @template2] }
    it('#vm_or_template_ids')             { @cluster.vm_or_template_ids.should             match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#direct_vm_or_template_ids')      { @cluster.direct_vm_or_template_ids.should      match_array [@vm1.id, @template1.id, @template2.id] }
    it('#total_direct_vms_and_templates') { @cluster.total_direct_vms_and_templates.should == 3 }

    it('#vms')              { @cluster.vms.should              match_array [@vm1, @vm2] }
    it('#direct_vms')       { @cluster.direct_vms.should       match_array [@vm1] }
    it('#vm_ids')           { @cluster.vm_ids.should           match_array [@vm1.id, @vm2.id] }
    it('#direct_vm_ids')    { @cluster.direct_vm_ids.should    match_array [@vm1.id] }
    it('#total_direct_vms') { @cluster.total_direct_vms.should == 1 }

    it('#miq_templates')              { @cluster.miq_templates.should              match_array [@template1, @template2] }
    it('#direct_miq_templates')       { @cluster.direct_miq_templates.should       match_array [@template1, @template2] }
    it('#miq_template_ids')           { @cluster.miq_template_ids.should           match_array [@template1.id, @template2.id] }
    it('#direct_miq_template_ids')    { @cluster.direct_miq_template_ids.should    match_array [@template1.id, @template2.id] }
    it('#total_direct_miq_templates') { @cluster.total_direct_miq_templates.should == 2 }

    it('#all_vms_and_templates')   { @cluster.all_vms_and_templates.should   match_array [@vm1, @vm2, @template1, @template2] }
    it('#all_vm_or_template_ids')  { @cluster.all_vm_or_template_ids.should  match_array [@vm1.id, @vm2.id, @template1.id, @template2.id] }
    it('#total_vms_and_templates') { @cluster.total_vms_and_templates.should == 4 }

    it('#all_vms')    { @cluster.all_vms.should    match_array [@vm1, @vm2] }
    it('#all_vm_ids') { @cluster.all_vm_ids.should match_array [@vm1.id, @vm2.id] }
    it('#total_vms')  { @cluster.total_vms.should  == 2 }

    it('#all_miq_templates')    { @cluster.all_miq_templates.should    match_array [@template1, @template2] }
    it('#all_miq_template_ids') { @cluster.all_miq_template_ids.should match_array [@template1.id, @template2.id] }
    it('#total_miq_templates')  { @cluster.total_miq_templates.should  == 2 }
  end

  it "#save_drift_state" do
    #TODO: Beef up with more data
    cluster = FactoryGirl.create(:ems_cluster)
    cluster.save_drift_state

    cluster.drift_states.size.should == 1
    DriftState.count.should == 1

    cluster.drift_states.first.data.should == {
      :aggregate_cpu_speed     => 0,
      :aggregate_logical_cpus  => 0,
      :aggregate_memory        => 0,
      :aggregate_physical_cpus => 0,
      :aggregate_vm_cpus       => 0,
      :aggregate_vm_memory     => 0,
      :class                   => "EmsCluster",
      :id                      => cluster.id,
      :name                    => cluster.name,

      :vms                     => [],
      :miq_templates           => [],
      :hosts                   => [],
    }
  end

  context("#perf_capture_enabled_host_ids=") do
    before do
      @miq_region = FactoryGirl.create(:miq_region, :region => 1)
      MiqRegion.stub(:my_region).and_return(@miq_region)
      @cluster = FactoryGirl.create(:ems_cluster)
      @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster)
      @host2 = FactoryGirl.create(:host, :ems_cluster => @cluster)
    end

    it "Initially Performance capture for cluster and its hosts should not be set" do
      @cluster.perf_capture_enabled.should eq(false)
      @host1.perf_capture_enabled.should eq(false)
      @host2.perf_capture_enabled.should eq(false)
    end

    it "Performance capture for cluster and its hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host1.id, @host2.id]
      @cluster.perf_capture_enabled.should eq(true)
      @host1.perf_capture_enabled.should eq(true)
      @host2.perf_capture_enabled.should eq(true)
    end

    it "Performance capture for cluster and only 1 hosts should be set" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      @cluster.perf_capture_enabled.should eq(true)
      @host1.perf_capture_enabled.should eq(false)
      @host2.perf_capture_enabled.should eq(true)
    end

    it "Performance capture for cluster and its hosts should get unset" do
      @cluster.perf_capture_enabled_host_ids = [@host2.id]
      @cluster.perf_capture_enabled_host_ids = []
      @cluster.perf_capture_enabled.should eq(false)
      @host1.perf_capture_enabled.should eq(false)
      @host2.perf_capture_enabled.should eq(false)
    end
  end
end
