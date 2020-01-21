module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :aggregate_cpu_speed,       :type => :integer, :uses => :hosts
    virtual_column :aggregate_cpu_total_cores, :type => :integer, :uses => :hosts
    virtual_column :aggregate_physical_cpus,   :type => :integer, :uses => :hosts
    virtual_column :aggregate_memory,          :type => :integer, :uses => :hosts
    virtual_column :aggregate_vm_cpus,         :type => :integer, :uses => :vms_and_templates
    virtual_column :aggregate_vm_memory,       :type => :integer, :uses => :vms_and_templates
    virtual_column :aggregate_disk_capacity,   :type => :integer, :uses => :hosts

    alias_method :all_hosts,              :hosts
    alias_method :all_host_ids,           :host_ids
    alias_method :all_vms_and_templates,  :vms_and_templates
    alias_method :all_vm_or_template_ids, :vm_or_template_ids
    alias_method :all_vms,                :vms
    alias_method :all_vm_ids,             :vm_ids
    alias_method :all_miq_templates,      :miq_templates
    alias_method :all_miq_template_ids,   :miq_template_ids

    include AggregationMixin::Methods
  end
end
