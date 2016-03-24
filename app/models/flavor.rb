class Flavor < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :vms

  virtual_column :total_vms, :type => :integer, :uses => :vms

  default_value_for :enabled, true

  def total_vms
    vms.size
  end

  def name_with_details
    details = if cpus == 1
                _("%{name} (%{num_cpus} CPU, %{memory_gigabytes} GB RAM, %{root_disk_gigabytes} GB Root Disk)")
              else
                _("%{name} (%{num_cpus} CPUs, %{memory_gigabytes} GB RAM, %{root_disk_gigabytes} GB Root Disk)")
              end
    details % {
      :name                => name,
      :num_cpus            => cpus,
      :memory_gigabytes    => memory.bytes / 1.0.gigabytes,
      :root_disk_gigabytes => root_disk_size.bytes / 1.0.gigabytes
    }
  end
end
