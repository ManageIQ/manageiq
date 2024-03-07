class Flavor < ApplicationRecord
  include NewWithTypeStiMixin
  include CloudTenancyMixin
  include SupportsFeatureMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :vms
  has_many   :cloud_tenant_flavors, :dependent => :destroy
  has_many   :cloud_tenants, :through => :cloud_tenant_flavors

  virtual_total :total_vms, :vms

  default_value_for :enabled, true

  alias_attribute :cpus, :cpu_total_cores
  alias_attribute :cpu_cores, :cpu_cores_per_socket

  virtual_column :cpus, :type => :integer
  virtual_column :cpu_cores, :type => :integer

  def name_with_details
    details = if cpus == 1
                if root_disk_size.nil?
                  _("%{name} (%{num_cpus} CPU, %{memory_gigabytes} GB RAM, Unknown Size Root Disk)")
                else
                  _("%{name} (%{num_cpus} CPU, %{memory_gigabytes} GB RAM, %{root_disk_gigabytes} GB Root Disk)")
                end
              else
                if root_disk_size.nil?
                  _("%{name} (%{num_cpus} CPUs, %{memory_gigabytes} GB RAM, Unknown Size Root Disk)")
                else
                  _("%{name} (%{num_cpus} CPUs, %{memory_gigabytes} GB RAM, %{root_disk_gigabytes} GB Root Disk)")
                end
              end
    details % {
      :name                => name,
      :num_cpus            => cpus,
      :memory_gigabytes    => memory.bytes / 1.0.gigabytes,
      :root_disk_gigabytes => root_disk_size && root_disk_size.bytes / 1.0.gigabytes
    }
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:Flavor)
  end

  def self.tenant_joins_clause(scope)
    scope.includes(:cloud_tenants => "source_tenant", :ext_management_system => {})
         .references(:cloud_tenants, :tenants, :ext_management_system)
  end

  # Create a flavor as a queued task and return the task id. The queue name and
  # the queue zone are derived from the provided EMS instance. The EMS instance
  # and a userid are mandatory.
  #
  def self.create_flavor_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "Creating flavor for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'Flavor',
      :method_name => 'create_flavor',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.raw_create_flavor(_ext_management_system, _options = {})
    raise NotImplementedError, "raw_create_flavor must be implemented in a subclass"
  end

  def self.create_flavor(ems_id, options)
    raise ArgumentError, _("ems cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ems cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:Flavor)
    klass.raw_create_flavor(ext_management_system, options)
  end

  # Delete a flavor as a queued task and return the task id. The queue name and
  # the queue zone are derived from the EMS, and a userid is mandatory.
  #
  def delete_flavor_queue(userid)
    task_opts = {
      :action => "Deleting flavor for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'Flavor',
      :method_name => 'delete_flavor',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_flavor
    raise NotImplementedError, _("raw_delete_flavor must be implemented in a subclass")
  end

  def delete_flavor
    raw_delete_flavor
  end
end
