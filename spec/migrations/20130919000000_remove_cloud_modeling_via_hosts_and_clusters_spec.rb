require "spec_helper"
require Rails.root.join("db/migrate/20130919000000_remove_cloud_modeling_via_hosts_and_clusters.rb")

describe RemoveCloudModelingViaHostsAndClusters do
  migration_context :up do
    let(:ems_stub)                   { migration_stub(:ExtManagementSystem) }
    let(:host_stub)                  { migration_stub(:Host) }
    let(:vm_stub)                    { migration_stub(:VmOrTemplate) }
    let(:cluster_stub)               { migration_stub(:EmsCluster) }
    let(:authentication_stub)        { migration_stub(:Authentication) }
    let(:tagging_stub)               { migration_stub(:Tagging) }
    let(:hardware_stub)              { migration_stub(:Hardware) }
    let(:relationship_stub)          { migration_stub(:Relationship) }
    let(:policy_event_stub)          { migration_stub(:PolicyEvent) }

    context "Amazon" do
      before(:each) do
        @ems = ems_stub.create!(:type => 'EmsAmazon')
      end

      it "does not remove the EMS without hosts and clusters" do

        migrate

        @ems.reload.should_not be_nil
      end

      it "removes the EMS" do
        should_be_deleted, should_not_be_deleted = build_ems_objects(@ems, 'Amazon')

        migrate

        should_be_deleted.each do |obj|
          lambda { obj.reload }.should     raise_error(ActiveRecord::RecordNotFound)
        end

        should_not_be_deleted.each do |obj|
          lambda { obj.reload }.should_not raise_error
        end
      end

      it "removes HostAmazon records with invalid/nil EMS" do
        cloud_type = 'Amazon'
        host       = host_stub.create!(:type => "Host#{cloud_type}")
        should_be_deleted, should_not_be_deleted = build_host_without_ems_objects(host, cloud_type)

        migrate

        should_be_deleted.each do |obj|
          lambda { obj.reload }.should     raise_error(ActiveRecord::RecordNotFound)
        end

        should_not_be_deleted.each do |obj|
          lambda { obj.reload }.should_not raise_error
        end
      end
    end

    context "Openstack" do
      before(:each) do
        @ems = ems_stub.create!(:type => 'EmsOpenstack')
      end

      it "does not remove the EMS without hosts and clusters" do

        migrate

        @ems.reload.should_not be_nil
      end

      it "removes the EMS" do
        should_be_deleted, should_not_be_deleted = build_ems_objects(@ems, 'Openstack')

        migrate

        should_be_deleted.each do |obj|
          lambda { obj.reload }.should     raise_error(ActiveRecord::RecordNotFound)
        end

        should_not_be_deleted.each do |obj|
          lambda { obj.reload }.should_not raise_error
        end
      end

      it "removes HostOpenstack records with invalid/nil EMS" do
        cloud_type = 'Openstack'
        host       = host_stub.create!(:type => "Host#{cloud_type}")
        should_be_deleted, should_not_be_deleted = build_host_without_ems_objects(host, cloud_type)

        migrate

        should_be_deleted.each do |obj|
          lambda { obj.reload }.should     raise_error(ActiveRecord::RecordNotFound)
        end

        should_not_be_deleted.each do |obj|
          lambda { obj.reload }.should_not raise_error
        end
      end
    end
  end

  def build_ems_objects(ems, cloud_type)
    host               = host_stub.create!(:type => "Host#{cloud_type}", :ems_id => ems.id)
    cluster            = cluster_stub.create!(:ems_id => ems.id)
    instance           = vm_stub.create!(:ems_id => ems.id, :type => "Vm#{cloud_type}")
    image              = vm_stub.create!(:ems_id => ems.id, :type => "Template#{cloud_type}")

    should_be_deleted = [ ems, host, cluster, instance, image ]

    should_be_deleted << authentication_stub.create!(:resource_id => ems.id, :resource_type => 'ExtManagementSystem')
    should_be_deleted << hardware_stub.create(:vm_or_template_id => instance.id)
    should_be_deleted << relationship_stub.create(:resource_id => instance.id, :resource_type => 'VmOrTemplate')
    should_be_deleted << relationship_stub.create(:resource_id => image.id, :resource_type => 'VmOrTemplate')
    should_be_deleted << policy_event_stub.create!(:ems_id => ems.id)
    should_be_deleted << tagging_stub.create!(:taggable_id => ems.id,      :taggable_type => 'ExtManagementSystem')
    should_be_deleted << tagging_stub.create!(:taggable_id => host.id,     :taggable_type => 'Host')
    should_be_deleted << tagging_stub.create!(:taggable_id => cluster.id,  :taggable_type => 'EmsCluster')
    should_be_deleted << tagging_stub.create!(:taggable_id => image.id,    :taggable_type => 'VmOrTemplate')
    should_be_deleted << tagging_stub.create!(:taggable_id => instance.id, :taggable_type => 'VmOrTemplate')

    # VMware EMS
    ems_vmware         = ems_stub.create!(:type => 'EmsVmware')
    cluster_vmware     = cluster_stub.create!(:ems_id => ems_vmware.id)
    host_vmware        = host_stub.create!(:type => 'HostVmware', :ems_id => ems_vmware.id)
    vm_vmware          = vm_stub.create!(:type => 'VmVmware', :ems_id => ems_vmware.id)

    should_not_be_deleted = [ ems_vmware, cluster_vmware, host_vmware, vm_vmware]

    should_not_be_deleted << hardware_stub.create(:vm_or_template_id => vm_vmware.id)
    should_not_be_deleted << tagging_stub.create!(:taggable_id => ems_vmware.id, :taggable_type => 'ExtManagementSystem')
    should_not_be_deleted << relationship_stub.create(:resource_id => vm_vmware.id, :resource_type => 'VmOrTemplate')

    return should_be_deleted, should_not_be_deleted
  end

  def build_host_without_ems_objects(host, cloud_type)
    instance           = vm_stub.create!(:host_id => host.id, :type => "Vm#{cloud_type}")
    image              = vm_stub.create!(:host_id => host.id, :type => "Template#{cloud_type}")

    should_be_deleted = [ host, instance, image ]

    should_be_deleted << hardware_stub.create(:vm_or_template_id => instance.id)
    should_be_deleted << relationship_stub.create(:resource_id => instance.id, :resource_type => 'VmOrTemplate')
    should_be_deleted << relationship_stub.create(:resource_id => image.id, :resource_type => 'VmOrTemplate')
    should_be_deleted << tagging_stub.create!(:taggable_id => host.id,     :taggable_type => 'Host')
    should_be_deleted << tagging_stub.create!(:taggable_id => image.id,    :taggable_type => 'VmOrTemplate')
    should_be_deleted << tagging_stub.create!(:taggable_id => instance.id, :taggable_type => 'VmOrTemplate')

    # VMware EMS
    host_vmware        = host_stub.create!(:type => 'HostVmware')
    vm_vmware          = vm_stub.create!(:type => 'VmVmware', :host_id => host_vmware.id)

    should_not_be_deleted = [ host_vmware, vm_vmware]

    should_not_be_deleted << hardware_stub.create(:vm_or_template_id => vm_vmware.id)
    should_not_be_deleted << relationship_stub.create(:resource_id => vm_vmware.id, :resource_type => 'VmOrTemplate')

    return should_be_deleted, should_not_be_deleted
  end

end
