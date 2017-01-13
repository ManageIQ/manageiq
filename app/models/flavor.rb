class Flavor < ApplicationRecord
  include NewWithTypeStiMixin

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
end
