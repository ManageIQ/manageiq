class RemoveCloudModelingViaHostsAndClusters < ActiveRecord::Migration

  class Tagging < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class Relationship < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class Hardware < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class PolicyEvent < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI

    has_many :ems_clusters,      :foreign_key => "ems_id", :dependent => :destroy, :class_name => "RemoveCloudModelingViaHostsAndClusters::EmsCluster"
    has_many :hosts,             :foreign_key => "ems_id", :dependent => :destroy, :class_name => "RemoveCloudModelingViaHostsAndClusters::Host"
    has_many :vms_and_templates, :foreign_key => "ems_id", :dependent => :destroy, :class_name => "RemoveCloudModelingViaHostsAndClusters::VmOrTemplate"
    has_many :policy_events,     :foreign_key => "ems_id", :dependent => :destroy, :class_name => "RemoveCloudModelingViaHostsAndClusters::PolicyEvent"
  end

  class EmsCluster < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
    has_many :vms_and_templates, :foreign_key => "host_id", :dependent => :destroy, :class_name => "RemoveCloudModelingViaHostsAndClusters::VmOrTemplate"
  end

  class VmOrTemplate < ActiveRecord::Base
    self.table_name = 'vms'
    self.inheritance_column = :_type_disabled    # disable STI
  end

  def up
    say_with_time("Removing Amazon Cloud Modeling via Hosts and Clusters") do
      emses = ExtManagementSystem.where(:type => 'EmsAmazon').includes(:vms_and_templates, :hosts, :ems_clusters)
      emses.each do |ems|
        remove_cloud_ems_modeled_via_infra(ems) if cloud_ems_modeled_via_infra?(ems)
      end

      Host.where(:type => 'HostAmazon').includes(:vms_and_templates).each do |host|
        remove_cloud_host(host)
      end
    end

    say_with_time("Removing Openstack Cloud Modeling via Hosts and Clusters") do
      emses = ExtManagementSystem.where(:type => 'EmsOpenstack').includes(:vms_and_templates, :hosts, :ems_clusters)
      emses.each do |ems|
        remove_cloud_ems_modeled_via_infra(ems) if cloud_ems_modeled_via_infra?(ems)
      end

      Host.where(:type => 'HostOpenstack').includes(:vms_and_templates).each do |host|
        remove_cloud_host(host)
      end
    end
  end

  def down
  end

  def cloud_ems_modeled_via_infra?(ems)
    (ems.hosts.count + ems.ems_clusters.count) > 0
  end

  def remove_cloud_ems_modeled_via_infra(ems)
    Tagging.where(       :taggable_id => ems.id, :taggable_type => 'ExtManagementSystem').delete_all
    Authentication.where(:resource_id => ems.id, :resource_type => 'ExtManagementSystem').delete_all

    vm_ids      = ems.vms_and_templates.collect(&:id)
    host_ids    = ems.hosts.collect(&:id)
    cluster_ids = ems.ems_clusters.collect(&:id)

    Tagging.where(:taggable_id => cluster_ids, :taggable_type => 'EmsCluster').delete_all
    Tagging.where(:taggable_id => host_ids,    :taggable_type => 'Host').delete_all
    Tagging.where(:taggable_id => vm_ids,      :taggable_type => 'VmOrTemplate').delete_all

    Hardware.where(:vm_or_template_id => vm_ids).delete_all # Templates have the guest_os in hardware
    Relationship.where(:resource_id => vm_ids, :resource_type => 'VmOrTemplate').delete_all # Genealogy

    ems.destroy
  end

  def remove_cloud_host(host)
    vm_ids = host.vms_and_templates.collect(&:id)

    Tagging.where(:taggable_id => host.id,     :taggable_type => 'Host').delete_all
    Tagging.where(:taggable_id => vm_ids,      :taggable_type => 'VmOrTemplate').delete_all

    Hardware.where(:vm_or_template_id => vm_ids).delete_all # Templates have the guest_os in hardware
    Relationship.where(:resource_id => vm_ids, :resource_type => 'VmOrTemplate').delete_all # Genealogy

    host.destroy
  end

end