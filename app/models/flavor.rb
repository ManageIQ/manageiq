class Flavor < ApplicationRecord
  include NewWithTypeStiMixin
  include CloudTenancyMixin
  include SupportsFeatureMixin

  supports :create
  supports :delete

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :vms
  has_many   :cloud_tenant_flavors, :dependent => :destroy
  has_many   :cloud_tenants, :through => :cloud_tenant_flavors

  virtual_total :total_vms, :vms

  default_value_for :enabled, true

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
      :root_disk_gigabytes => root_disk_size.nil? ? nil : root_disk_size.bytes / 1.0.gigabytes
    }
  end

  def self.tenant_joins_clause(scope)
    scope.includes(:cloud_tenants => "source_tenant").includes(:ext_management_system)
  end
  def delete_flavor_queue(userid)
    task_opts = {
      :action => "Deleting flavor for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'Flavor',
      :method_name => 'delete_flavor',
      :role        => 'ems operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_flavor
    raise NotImplementedError, _("raw_delete_flavor must be implemented in a subclass")
  end

  def validate_delete_flavor
    validate_unsupported(_("Delete Flavor Operation"))
  end

  def delete_flavor
    raw_delete_flavor
  end

  def delete_flavor_queue(userid)
    task_opts = {
      :action => "Deleting flavor for user #{userid}",
      :userid => userid
    }
    binding.pry
    queue_opts = {
      :class_name  => 'Flavor',
      :method_name => 'delete_flavor',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_flavor
    raise NotImplementedError, _("raw_delete_flavor must be implemented in a subclass")
  end

  def validate_delete_flavor
    validate_unsupported(_("Delete Flavor Operation"))
  end

  def delete_flavor
    raw_delete_flavor
  end

  def validate_unsupported(message_prefix)
    {:available => false,
     :message   => _("%<message>s is not available for %<name>s.") % {:message => message_prefix, :name => name}}
  end
end
