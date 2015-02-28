require "spec_helper"

describe VmdbwsController, :apis => true do

  before(:each) do
    MiqRegion.seed

    super_role   = FactoryGirl.create(:ui_task_set, :name => 'super_administrator2', :description => 'Super Administrator')
    @admin       = FactoryGirl.create(:user, :name => 'admin',            :userid => 'admin2',    :ui_task_set_id => super_role.id)
    ApplicationController.any_instance.stub(:set_user_time_zone)

    ::UiConstants
    @controller = VmdbwsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stub(:authenticate).and_return(true)
    @controller.instance_variable_set(:@username, "admin")
  end

  it 'should send a web-service ping to the server' do
    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(guid)
    MiqServer.my_server_clear_cache
    miq_server = FactoryGirl.create(:miq_server, :guid => guid, :zone => FactoryGirl.create(:zone, :name => "fred"))

    invoke(:EVM_ping, "valid").should be_true
  end

  it 'should return a version string' do
    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(guid)
    MiqServer.my_server_clear_cache
    miq_server = FactoryGirl.create(:miq_server, :guid => guid, :zone => FactoryGirl.create(:zone, :name => "fred"))

    result = invoke(:Version)
    result.should be_kind_of(Array)
    result.should have_at_least(2).items    # version = [maj, min, build, x, build] or ["master", build]
    result.each {|ver| ver.should be_kind_of(String)}
  end

  #ems
  it 'should return a list of all Management Systems' do
    _guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:ems_vmware)

    result = invoke(:GetEmsList)
    ems = invoke(:GetEmsByList, result)
    validate_ci_list(result, VmdbwsSupport::EmsList)
    ems.should have(ExtManagementSystem.count).things
    result.should have(ExtManagementSystem.count).things
    ems.first.ws_attributes.count.should == get_ws_attribute_count(ExtManagementSystem)
  end

  it 'should return Management information for FindEmsByGuid' do
    _guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:ems_vmware)

    db_ems = ExtManagementSystem.first
    ems = invoke(:FindEmsByGuid,db_ems.guid)
    ems.guid.should == db_ems.guid
  end

  it 'should raise an error for invalid ems guid for FindEmsByGuid' do
    lambda {invoke(:FindEmsByGuid,"1234")}.should raise_error(RuntimeError)
  end

  it 'should raise an error for invalid ems guid for EmsGetTags' do
    lambda {invoke(:EmsGetTags,"1234")}.should raise_error(RuntimeError)
  end

  it "should be able to get and set ems tags" do
    _guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:ems_vmware)

    FactoryGirl.create(:classification_cost_center_with_tags)
    ems = ExtManagementSystem.first
    invoke(:EmsGetTags, ems.guid).should == []
    invoke(:EmsSetTag, ems.guid, "cc", "001" )
    res = invoke(:EmsGetTags, ems.guid)
    res.should have(1).thing
    result = res.first
    result.tag_name.should == "001"
    result.display_name.should == "Cost Center: Cost Center 001"
    result.tag_path.should == "/managed/cc/001"
    result.category.should == "cc"
    result.tag_display_name.should == "Cost Center 001"
  end

  #hosts
  it 'should return a list of all Hosts' do
    FactoryGirl.create(:host_vmware)
    result = invoke(:GetHostList,'*')
    hosts = invoke(:GetHostsByList, result)
    validate_ci_list(result, VmdbwsSupport::HostList)
    hosts.should have(Host.count).things
    result.should have(Host.count).things
  end

  it 'should return Host ws attributes' do
    ems = FactoryGirl.create(:ems_vmware)
    FactoryGirl.create(:host_vmware, :ext_management_system => ems)
    ems_list = invoke(:GetEmsList)
    result = invoke(:GetHostList, ems.guid)
    hosts = invoke(:GetHostsByList, result)
    hosts.first.ws_attributes.count.should == get_ws_attribute_count(Host)
  end

  it 'should return hardware information for a host' do
    ems  = FactoryGirl.create(:ems_vmware)
    hardware = FactoryGirl.create(:hardware, :numvcpus => '2', :memory_cpu => '1234')
    host = FactoryGirl.create(:host_vmware, :ext_management_system => ems, :hardware => hardware)
    ems_list = invoke(:GetEmsList)
    result = invoke(:GetHostList, ems.guid)
    hosts = invoke(:GetHostsByList, result)
    host = hosts.first
    host.hardware.should_not be_nil
    host.hardware.numvcpus.to_i.should == 2
    host.hardware.memory_cpu.to_i.should == 1234
  end

  # WAT?
  it 'should return Host information' do
    FactoryGirl.create(:host_vmware)
    hosts = invoke(:GetHostList,'*')
    host_info = invoke(:EVM_get_host, hosts.first.guid)
    validate_ci_list(hosts, VmdbwsSupport::HostList)
  end

  it 'should return Host information for FindHostByGuid' do
    hardware = FactoryGirl.create(:hardware, :numvcpus => '2', :memory_cpu => '1234')
    host = FactoryGirl.create(:host_vmware, :hardware => hardware)

    host = invoke(:FindHostByGuid,host.guid)
    host.hardware.should be_kind_of(VmdbwsSupport::ProxyHardware)
    host.hardware.id.should == host.hardware.id.to_s
  end

  it 'should raise an error for invalid host guid for FindHostByGuid' do
    lambda {invoke(:FindHostByGuid,"1234")}.should raise_error(RuntimeError)
  end

  it 'should raise an error for invalid host guid for HostGetTags' do
    lambda {invoke(:HostGetTags,"1234")}.should raise_error(RuntimeError)
  end

  #clusters
  it 'should return a list of all Clusters' do
    FactoryGirl.create(:ems_cluster)
    result = invoke(:GetClusterList, '*')
    clusters = invoke(:GetClustersByList,result)
    validate_ci_list(result, VmdbwsSupport::ClusterList, '@id')
    result.should have(1).things
    clusters.should have(1).things
  end

  it 'should return Cluster information using old style EVM methods' do
    cluster = FactoryGirl.create(:ems_cluster)
    result = invoke(:EVM_cluster_list, '*')
    validate_ci_list(result, VmdbwsSupport::ClusterList, '@id')
    result.should have(1).things
    cluster = invoke(:EVM_get_cluster, cluster.id)
    cluster.name.should == result.first.name
  end

  it 'should return Cluster ws attributes' do
    FactoryGirl.create(:ems_cluster)
    result = invoke(:GetClusterList, '*')
    result.should have(1).things
    clusters = invoke(:GetClustersByList,result)
    clusters.first.ws_attributes.count.should == get_ws_attribute_count(EmsCluster)
  end

  it 'should return a list of Clusters for an EMS' do
    ems  = FactoryGirl.create(:ems_vmware)
    cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
    result = invoke(:GetClusterList, ems.guid)
    result.should have(1).things
  end

  it 'should return tagged Clusters' do
    cluster = FactoryGirl.create(:ems_cluster)
    cluster.tag_with("/managed/cc/test", :ns=>"*")
    EmsCluster.find_tagged_with(:all => 'cc/test', :ns => '/managed').all.should have(1).thing
    invoke(:GetClustersByTag, "cc/test").should have(1).thing
  end

  it 'should return Cluster information for FindClusterById' do
    ems  = FactoryGirl.create(:ems_vmware)
    new_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
    all_clusters = invoke(:FindClustersById,[new_cluster.id])
    all_clusters.should have(1).things
    cluster = invoke(:FindClusterById,new_cluster.id)
    cluster.ext_management_system.guid.should == ems.guid
  end

  it 'should raise an error for invalid cluster id for FindClusterById' do
    lambda {invoke(:FindClustersById, ["1234"])}.should raise_error(RuntimeError)
  end

  it 'should raise an error for invalid cluster id for ClusterGetTags' do
    lambda {invoke(:ClusterGetTags,"1234")}.should raise_error(RuntimeError)
  end

  #resource_pools
  it 'should return a list of all Resource Pools' do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)
    result = invoke(:GetResourcePoolList, '*')
    resource_pools = invoke(:GetResourcePoolsByList,result)
    validate_ci_list(result, VmdbwsSupport::ResourcePoolList,'@id')
    result.should have(1).things
    resource_pools.should have(1).things
  end

  it 'should return Resource Pool information using old style EVM methods' do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)
    result = invoke(:EVM_resource_pool_list, '*')
    validate_ci_list(result, VmdbwsSupport::ResourcePoolList, '@id')
    result.should have(1).things
    resourcepool = invoke(:EVM_get_resource_pool, result.first.id)
    resourcepool.name.should == result.first.name
  end

  it 'should return Resource Pool ws attributes' do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)
    result = invoke(:GetResourcePoolList, '*')
    result.should have(1).things
    resourcepools = invoke(:GetResourcePoolsByList,result)
    resourcepools.first.ws_attributes.count.should == get_ws_attribute_count(ResourcePool)
  end

  it 'should return a list of all Resource Pools for a given ems' do
    ems = FactoryGirl.create(:ems_vmware)
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool, :ext_management_system => ems)
    pool.set_parent(cluster)
    result = invoke(:GetResourcePoolList, ems.guid)
    resource_pools = invoke(:GetResourcePoolsByList,result)
    resource_pools.should have(1).things
  end

  it 'should return tagged Resource Pools' do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)

    pool.tag_with("/managed/cc/test", :ns=>"*")
    ResourcePool.find_tagged_with(:all => 'cc/test', :ns => '/managed').all.should have(1).thing
    invoke(:GetResourcePoolsByTag, "cc/test").should have(1).thing
  end

  it 'should return Resource Pool information for FindResourcePoolById' do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)

    pools = invoke(:FindResourcePoolsById,[pool.id])
    pools.should have(1).things
    resource_pool = invoke(:FindResourcePoolById, pool.id)
    resource_pool.id.to_i.should == pool.id
  end

  it 'should raise an error for invalid resource pool id for FindResourcePoolById' do
    lambda {invoke(:FindResourcePoolsById, ["1234"])}.should raise_error(RuntimeError)
  end

  it 'should raise an error for invalid resource pool id for ResourcePoolGetTags' do
    lambda {invoke(:ResourcePoolGetTags, "1234")}.should raise_error(RuntimeError)
  end

  it "should be able to get and set resourcepool tags" do
    cluster = FactoryGirl.create(:ems_cluster)
    pool = FactoryGirl.create(:resource_pool)
    pool.set_parent(cluster)

    FactoryGirl.create(:classification_cost_center_with_tags)

    invoke(:ResourcePoolGetTags, pool.id).should == []
    invoke(:ResourcePoolSetTag, pool.id, "cc", "001" )
    res = invoke(:ResourcePoolGetTags, pool.id)
    res.should have(1).thing
    result = res.first
    result.tag_name.should == "001"
    result.display_name.should == "Cost Center: Cost Center 001"
    result.tag_path.should == "/managed/cc/001"
    result.category.should == "cc"
    result.tag_display_name.should == "Cost Center 001"
  end

  #datastores
  it 'should return a list of all Datastores' do
    FactoryGirl.create(:storage)
    result = invoke(:GetDatastoreList, '*')
    datastores = invoke(:GetDatastoresByList,result)
    validate_ci_list(result, VmdbwsSupport::DatastoreList,'@id')
    result.should have(1).things
    datastores.should have(1).things
  end

  it 'should return a list of Datastores for an ems' do
    ems = FactoryGirl.create(:ems_vmware)
    host = FactoryGirl.create(:host_vmware, :ext_management_system => ems)
    storage = FactoryGirl.create(:storage)
    storage.hosts << host

    result = invoke(:GetDatastoreList, ems.guid)
    datastores = invoke(:GetDatastoresByList,result)
    validate_ci_list(result, VmdbwsSupport::DatastoreList,'@id')
    result.should have(1).things
  end

  it 'should return Datastore information using old style EVM methods' do
    FactoryGirl.create(:storage)
    result = invoke(:EVM_datastore_list, '*')
    validate_ci_list(result, VmdbwsSupport::DatastoreList, '@id')
    result.should have(1).things
    datastore = invoke(:EVM_get_datastore, result.first.id)
    datastore.name.should == result.first.name
  end

  it 'should return Datastore ws attributes' do
    FactoryGirl.create(:storage)
    result = invoke(:GetDatastoreList, '*')
    result.should have(1).things
    datastores = invoke(:GetDatastoresByList,result)
    datastores.first.ws_attributes.count.should == get_ws_attribute_count(Storage)
  end

  it 'should return tagged Datastores' do
    datastore = FactoryGirl.create(:storage)
    datastore.tag_with("/managed/cc/test", :ns=>"*")
    Storage.find_tagged_with(:all => 'cc/test', :ns => '/managed').all.should have(1).thing
    invoke(:GetDatastoresByTag, "cc/test").should have(1).thing
  end

  it 'should return Datastore information for FindDatastoreById' do
    db_datastore = FactoryGirl.create(:storage)
    all_datastores = invoke(:FindDatastoresById, [db_datastore.id])
    all_datastores.should have(1).things

    datastore = invoke(:FindDatastoreById, db_datastore.id)
    datastore.id.to_i.should == db_datastore.id
  end

  it 'should raise an error for invalid datastore id for FindDatastoresById' do
    lambda {invoke(:FindDatastoresById, ["1234"])}.should raise_error(RuntimeError)
  end

  it 'should raise an error for invalid datastore id for DatastoreGetTags' do
    lambda {invoke(:DatastoreGetTags,"1234")}.should raise_error(RuntimeError)
  end

  it "should be able to get and set datastore tags" do
    FactoryGirl.create(:classification_cost_center_with_tags)

    datastore = FactoryGirl.create(:storage)
    invoke(:DatastoreGetTags, datastore.id).should == []
    invoke(:DatastoreSetTag, datastore.id, "cc", "001" )
    res = invoke(:DatastoreGetTags, datastore.id)
    res.should have(1).thing
    result = res.first
    result.tag_name.should == "001"
    result.display_name.should == "Cost Center: Cost Center 001"
    result.tag_path.should == "/managed/cc/001"
    result.category.should == "cc"
    result.tag_display_name.should == "Cost Center 001"
  end

  #vms
  it 'should return a list of all VMs' do
    FactoryGirl.create(:vm_vmware)
    result = invoke(:EVM_vm_list, '*')
    validate_ci_list(result, VmdbwsSupport::VmList)
    result.should have(1).things
    result = invoke(:EVM_vm_list, 'all')
    validate_ci_list(result, VmdbwsSupport::VmList)
    result.should have(1).things
    result = invoke(:EVM_vm_list, 'none')
    validate_ci_list(result, VmdbwsSupport::VmList)
    result.should have(1).things
  end

  it 'should return VM ws attributes' do
    FactoryGirl.create(:vm_vmware)
    result = invoke(:EVM_vm_list, '*')
    vms = invoke(:GetVmsByList,result)
    vms.first.ws_attributes.count.should == get_ws_attribute_count(Vm)
  end

  it 'should return a list of VMs for a single host' do
    db_host = FactoryGirl.create(:host_vmware)
    db_vm = FactoryGirl.create(:vm_vmware, :host => db_host)

    hosts = invoke(:EVM_host_list)
    host = hosts.first
    result = invoke(:EVM_vm_list, db_host.guid)
    validate_ci_list(result, VmdbwsSupport::VmList)
    result.should have(1).things
  end

  it 'should return hardware information for a VM' do
    hardware = FactoryGirl.create(:hardware, :numvcpus => '2', :memory_cpu => '1234')
    FactoryGirl.create(:vm_vmware, :hardware => hardware)

    result = invoke(:GetVmList, "*")
    vm = invoke(:GetVmsByList, result).first
    vm.hardware.should_not be_nil
    vm.hardware.numvcpus.to_i.should == 2
    vm.hardware.memory_cpu.to_i.should == 1234
  end

  it 'should return tagged VMs' do
    vm = FactoryGirl.create(:vm_vmware)
    template = FactoryGirl.create(:miq_template, :name => "template", :location => "abc/abc.vmtx", :template => true, :vendor => "vmware")
    Vm.find_tagged_with(:all => 'cc/001', :ns => '/managed').all.should be_empty
    invoke(:GetVmsByTag, "cc/001").should be_empty
    vm.tag_with("/managed/cc/001", :ns=>"*")
    Vm.find_tagged_with(:all => 'cc/001', :ns => '/managed').all.should have(1).thing
    invoke(:GetVmsByTag, "cc/001").should have(1).thing
    # In v 4.x templates are returned with VMs
    template.tag_with("/managed/cc/001", :ns=>"*")
    Vm.find_tagged_with(:all => 'cc/001', :ns => '/managed').all.should have(1).thing
    invoke(:GetVmsByTag, "cc/001").should have(1).thing
  end

  it "should be able to get and set vm tags" do
    FactoryGirl.create(:classification_cost_center_with_tags)

    vm = FactoryGirl.create(:vm_vmware)
    invoke(:VmGetTags, vm.guid).should == []
    invoke(:VmSetTag, vm.guid, "cc", "001")
    res = invoke(:VmGetTags, vm.guid)
    res.should have(1).thing
    result = res.first
    result.tag_name.should == "001"
    result.display_name.should == "Cost Center: Cost Center 001"
    result.tag_path.should == "/managed/cc/001"
    result.category.should == "cc"
    result.tag_display_name.should == "Cost Center 001"
  end

  it "invoke :VmGetTags" do
    vm = FactoryGirl.create(:vm_vmware)
    invoke(:VmGetTags, vm.guid).should == []

    cl = FactoryGirl.create(:classification, :name => "one", :description => "two")
    vm.tag_with(cl.tag.name, :ns=>"*")
    res = invoke(:VmGetTags, vm.guid)

    res.should have(1).thing
    result = res.first
    result.tag_name.should == "one"
    result.display_name.should == "two: two"
    result.tag_path.should == "/managed/one"
    result.category.should == "one"
    result.tag_display_name.should == "two"
  end

  it "should be able to get and set cluster tags" do
    FactoryGirl.create(:classification_cost_center_with_tags)
    cluster = FactoryGirl.create(:ems_cluster)

    invoke(:ClusterGetTags, cluster.id).should == []
    invoke(:ClusterSetTag, cluster.id, "cc", "001" )
    res = invoke(:ClusterGetTags, cluster.id)
    res.should have(1).thing
    result = res.first
    result.tag_name.should == "001"
    result.display_name.should == "Cost Center: Cost Center 001"
    result.tag_path.should == "/managed/cc/001"
    result.category.should == "cc"
    result.tag_display_name.should == "Cost Center 001"
  end

  it 'should return tagged Templates' do
    vm = FactoryGirl.create(:vm_vmware)
    template = FactoryGirl.create(:miq_template, :name => "template", :location => "abc/abc.vmtx", :template => true, :vendor => "vmware")

    MiqTemplate.find_tagged_with(:all => 'cc/001', :ns => '/managed').all.should be_empty
    invoke(:GetTemplatesByTag, "cc/001").should be_empty
    vm.tag_with("/managed/cc/001", :ns=>"*")
    invoke(:GetTemplatesByTag, "cc/001").should be_empty
    template.tag_with("/managed/cc/001", :ns=>"*")
    invoke(:GetTemplatesByTag, "cc/001").should have(1).things
  end

  context "With a small environment containing a cluster with resource pools" do
    before(:each) do
      FactoryGirl.create(:small_environment_cluster_with_resource_pools)
    end

    it 'should return Management Systems relationships' do
      result = invoke(:GetEmsList)
      result.should have(ExtManagementSystem.count).things
      emss = invoke(:GetEmsByList, result)
      ems = emss.first
      db_ems = ExtManagementSystem.find_by_id(ems.id)
      ems.clusters.count.should == db_ems.ems_clusters.count
      ems.clusters.first.should be_kind_of(VmdbwsSupport::ClusterList)
      ems.clusters.first.id.should == EmsCluster.first.id.to_s
      ems.vms.count.should == db_ems.vms.count
      ems.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      db_vm = Vm.find_by_guid(ems.vms.first.guid)
      ems.vms.first.guid.should == db_vm.guid
      ems.hosts.count.should == db_ems.hosts.count
      ems.hosts.first.should be_kind_of(VmdbwsSupport::HostList)
      ems.hosts.first.guid.should == Host.first.guid.to_s
      ems.resource_pools.count.should == db_ems.resource_pools.count
      ems.resource_pools.first.should be_kind_of(VmdbwsSupport::ResourcePoolList)
      ems.resource_pools.first.id.should == ResourcePool.first.id.to_s
      ems.datastores.count.should == db_ems.storages.count
      ems.datastores.first.should be_kind_of(VmdbwsSupport::DatastoreList)
      ems.datastores.first.id.should == Storage.first.id.to_s
    end

    it 'should return Host relationships' do
      ems_list = invoke(:GetEmsList)
      result = invoke(:GetHostList,ems_list.last.guid)
      hosts = invoke(:GetHostsByList, result)
      host = hosts.first
      db_host = Host.find_by_id(host.id)
      host.ems_id.should == db_host.ems_id.to_s
      host.vms.count.should == db_host.vms.count
      host.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      db_vm = Vm.find_by_guid(host.vms.first.guid)
      host.vms.first.guid.should == db_vm.guid
      host.datastores.count.should == db_host.storages.count
      host.datastores.first.should be_kind_of(VmdbwsSupport::DatastoreList)
      db_storage = Storage.find_by_id(host.datastores.first.id)
      host.datastores.first.id.should == db_storage.id.to_s
      host.parent_cluster.should be_kind_of(VmdbwsSupport::ClusterList)
      host.parent_cluster.id.should == db_host.parent_cluster.id.to_s
      host.resource_pools.should be_empty
    end

    it 'should return Cluster relationships' do
      result = invoke(:GetClusterList, '*')
      clusters = invoke(:GetClustersByList,result)
      cluster = clusters.first
      db_cluster = EmsCluster.find_by_id(result.first.id)
      cluster.ext_management_system.guid.should == db_cluster.ext_management_system.guid
      db_host = Host.find_by_guid(cluster.hosts.first.guid)
      cluster.hosts.first.guid.should == db_host.guid.to_s
      cluster.hosts.count.should == db_cluster.hosts.count
      cluster.hosts.first.should be_kind_of(VmdbwsSupport::HostList)
      db_resource_pool = ResourcePool.find_by_id(cluster.resource_pools.first.id)
      cluster.resource_pools.first.id.should == db_resource_pool.id.to_s
      cluster.resource_pools.count.should == db_cluster.resource_pools.count
      cluster.resource_pools.first.should be_kind_of(VmdbwsSupport::ResourcePoolList)
      db_vm = Vm.find_by_guid(cluster.vms.first.guid)
      cluster.vms.first.guid.should == db_vm.guid
      cluster.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      cluster.vms.count.should == db_cluster.vms.count
      db_storage = Storage.find_by_id(cluster.datastores.first.id)
      cluster.datastores.first.id.should == db_storage.id.to_s
      cluster.datastores.first.should be_kind_of(VmdbwsSupport::DatastoreList)
      cluster.datastores.count.should == db_cluster.storages.count
    end

    it 'should return Resource Pool relationships' do
      result = invoke(:GetResourcePoolList, '*')
      resource_pools = invoke(:GetResourcePoolsByList,result)
      resource_pool = resource_pools.first
      db_resource_pool = ResourcePool.find_by_id(result.first.id)
      resource_pool.ext_management_system.guid.should == db_resource_pool.ext_management_system.guid
      db_vm = Vm.find_by_guid(resource_pool.vms.first.guid)
      resource_pool.vms.first.guid.should == db_vm.guid
      resource_pool.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      resource_pool.vms.count.should == db_resource_pool.vms.count
      db_cluster = EmsCluster.find_by_id(resource_pool.parent_cluster.id)
      resource_pool.parent_cluster.id.should == db_cluster.id.to_s
      resource_pool.parent_cluster.should be_kind_of(VmdbwsSupport::ClusterList)
    end

    it 'should return Datastore relationships' do
      result = invoke(:GetDatastoreList, '*')
      datastores = invoke(:GetDatastoresByList,result)
      datastore = datastores.first
      db_storage = Storage.find_by_id(result.first.id)
      datastore.vms.count.should == db_storage.vms.count
      datastore.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      db_vm = Vm.find_by_guid(datastore.vms.first.guid)
      datastore.vms.first.guid.should == db_vm.guid
      datastore.all_vms.count.should == db_storage.all_vms.count
      datastore.all_vms.first.should be_kind_of(VmdbwsSupport::VmList)
      datastore.hosts.count.should == db_storage.hosts.count
      datastore.hosts.first.should be_kind_of(VmdbwsSupport::HostList)
      datastore.hosts.first.guid.should == Host.first.guid.to_s
      datastore.ext_management_systems.first.should be_kind_of(VmdbwsSupport::EmsList)
      datastore.ext_management_systems.first.guid.should == ExtManagementSystem.first.guid.to_s
    end

    it 'should return VM relationships' do
      result = invoke(:EVM_vm_list, '*')
      vms = invoke(:GetVmsByList,result)
      vm = vms.first
      db_vm = Vm.find_by_guid(vm.guid)
      vm.ext_management_system.guid.should == db_vm.ext_management_system.guid
      vm.guid.should == db_vm.guid
      vm.host.should be_kind_of(VmdbwsSupport::HostList)
      vm.host.guid.should == db_vm.host.guid.to_s
      vm.host.guid.should == Host.first.guid.to_s
      vm.datastores.count.should == db_vm.storages.count
      vm.datastores.first.should be_kind_of(VmdbwsSupport::DatastoreList)
      db_storage = Storage.find_by_id(vm.datastores.first.id)
      vm.datastores.first.id.should == db_storage.id.to_s
      db_resource_pool = ResourcePool.find_by_id(vm.parent_resource_pool.id)
      vm.parent_resource_pool.id.should == db_resource_pool.id.to_s
    end
  end

  context "With a small environment containing a host with 2 resource pools" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment_host_with_resource_pools)
    end

    it 'should return Host resource pool relationships' do
      ems_list = invoke(:GetEmsList)
      result = invoke(:GetHostList,ems_list.last.guid)
      hosts = invoke(:GetHostsByList, result)
      host = hosts.first
      db_host = Host.find_by_id(host.id)
      host.ems_id.should == db_host.ems_id.to_s
      host.vms.count.should == db_host.vms.count
      host.vms.first.should be_kind_of(VmdbwsSupport::VmList)
      db_vm = Vm.find_by_guid(host.vms.first.guid)
      host.vms.first.guid.should == db_vm.guid
      host.datastores.count.should == db_host.storages.count
      host.datastores.first.should be_kind_of(VmdbwsSupport::DatastoreList)
      db_storage = Storage.find_by_id(host.datastores.first.id)
      host.datastores.first.id.should == db_storage.id.to_s
      host.parent_cluster.should be_nil
      host.resource_pools.first.should be_kind_of(VmdbwsSupport::ResourcePoolList)
      host.resource_pools.first.id.should == db_host.resource_pools.first.id.to_s
    end

    it 'should return 2 resources pools incuding the default resource pool for hosts ' do
      ems_list = invoke(:GetEmsList)
      ExtManagementSystem.count.should == 1
      Host.count.should == 1
      Vm.count.should == 2
      Storage.count.should == 2
      EmsCluster.count.should == 0
      ResourcePool.count.should == 2
      ExtManagementSystem.first.storages.count.should == 2
      Host.first.storages.count.should == 2
      Vm.all.each {|v| v.storage.should_not be_nil}
      Vm.all.each {|v| v.v_owning_resource_pool.should_not be_nil}
      Host.all.each {|h| h.v_owning_cluster.should == ""}
      Vm.all.each   {|v| v.v_owning_cluster.should == ""}
      db_host = Host.first
      db_host.resource_pools_with_default.count.should == 2
      db_host.resource_pools.count.should == 1
      db_host.default_resource_pool.should == ResourcePool.first
      # see if we are returning the sames values
      ems_list = invoke(:GetEmsList)
      result = invoke(:GetHostList,ems_list.first.guid)
      hosts = invoke(:GetHostsByList, result )
      hosts.first.resource_pools.count.should == 1
      hosts.first.default_resource_pool.id.should == ResourcePool.first.id.to_s
    end
  end

  context "With a small environment containing a cluster and a default resource pool" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment_cluster_with_default_resource_pool)
    end

    it 'should return default resource pool for cluster ' do
      ExtManagementSystem.count.should == 1
      Host.count.should == 1
      Vm.count.should == 2
      Storage.count.should == 2
      EmsCluster.count.should == 1
      ResourcePool.count.should == 1
      ExtManagementSystem.first.storages.count.should == 2
      Host.first.storages.count.should == 2
      EmsCluster.first.storages.count.should == 2 if @env_type == :small_environment_with_storage_and_cluster
      Vm.all.each {|v| v.storage.should_not be_nil}
      Vm.all.each {|v| v.v_owning_resource_pool.should_not be_nil}
      db_cluster = EmsCluster.first
      db_cluster.resource_pools_with_default.count.should == 1
      db_cluster.resource_pools.count.should == 0
      db_cluster.default_resource_pool.should == ResourcePool.first
      db_host = Host.first
      db_host.resource_pools_with_default.count.should == 0
      db_host.resource_pools.count.should == 0
      db_host.default_resource_pool.should be_nil
      Host.all.each {|h| h.parent_cluster.should == db_cluster}
      Vm.all.each   {|v| v.parent_cluster.should == db_cluster}
      # see if we are returning the sames values
      ems_list = invoke(:GetEmsList)
      result = invoke(:GetHostList,ems_list.first.guid)
      hosts = invoke(:GetHostsByList, result )
      hosts.first.resource_pools.count.should == 0
      hosts.first.default_resource_pool.should be_nil
      result = invoke(:GetClusterList, '*')
      clusters = invoke(:GetClustersByList,result)
      clusters.first.resource_pools.count.should == 0
      clusters.first.default_resource_pool.id.should == ResourcePool.first.id.to_s
    end
  end

  context "With a small environment containing a host with a default resource pool" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment_host_with_default_resource_pool)
    end

    it 'should return default resource pool for host ' do
      ExtManagementSystem.count.should == 1
      Host.count.should == 1
      Vm.count.should == 2
      Storage.count.should == 2
      EmsCluster.count.should == 0
      ResourcePool.count.should == 1
      ExtManagementSystem.first.storages.count.should == 2
      Host.first.storages.count.should == 2
      Vm.all.each {|v| v.storage.should_not be_nil}
      Vm.all.each {|v| v.v_owning_resource_pool.should_not be_nil}
      Host.all.each {|h| h.v_owning_cluster.should == ""}
      Vm.all.each   {|v| v.v_owning_cluster.should == ""}
      db_host = Host.first
      db_host.resource_pools_with_default.count.should == 1
      db_host.resource_pools.count.should == 0
      db_host.default_resource_pool.should == ResourcePool.first
      # see if we are returning the sames values
      ems_list = invoke(:GetEmsList)
      result = invoke(:GetHostList,ems_list.first.guid)
      hosts = invoke(:GetHostsByList, result )
      hosts.first.resource_pools.count.should == 0
      hosts.first.default_resource_pool.id.should == ResourcePool.first.id.to_s
    end

  end

    def validate_ci_list(cis, klass, var = "@guid")
      cis.should be_kind_of(Array)
      ci = cis.first
      ci.should be_an_instance_of(klass)
      ci.instance_variables.should have(2).things
      ci.instance_variables.any? { |v| v.to_s == "@name"  }.should be_true
      ci.instance_variables.any? { |v| v.to_s == var.to_s  }.should be_true
    end

    def get_ws_attribute_count(klass)
      web_service_skip_attrs = ['memory_exceeds_current_host_headroom']
      count = 0
      klass.virtual_columns_hash.each do |k, v|
        next if web_service_skip_attrs.include?(k)
        next if k =~ /enabled_.*ports$/
        next if k.include?("password")
        next if k =~ /custom_\d/
        count += 1
      end
      count
    end

end
