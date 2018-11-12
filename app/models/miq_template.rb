class MiqTemplate < VmOrTemplate
  include CustomActionsMixin

  default_scope { where(:template => true) }

  virtual_column :display_type,                         :type => :string
  virtual_column :display_operating_system,             :type => :string
  virtual_column :display_platform,                     :type => :string
  virtual_column :display_cpu_cores,                    :type => :string
  virtual_column :display_memory,                       :type => :string
  virtual_column :display_snapshots,                    :type => :string
  virtual_column :display_tenant,                       :type => :string
  virtual_column :display_deprecated,                   :type => :string

  include_concern 'Operations'

  def self.base_model
    MiqTemplate
  end

  def self.corresponding_model
    parent::Vm
  end
  class << self; alias_method :corresponding_vm_model, :corresponding_model; end

  delegate :corresponding_model, :to => :class
  alias_method :corresponding_vm_model, :corresponding_model

  def scan_via_ems?
    true
  end

  def self.supports_kickstart_provisioning?
    false
  end

  delegate :supports_kickstart_provisioning?, :to => :class

  def self.eligible_for_provisioning
    where(arel_table[:ems_id].not_eq(nil))
  end

  def self.without_volume_templates
    where.not(:type => ["ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate",
                        "ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate"])
  end

  def active?; false; end

  def self.display_name(number = 1)
    n_('Template and Image', 'Templates and Images', number)
  end

  def self.non_deprecated
    where(:deprecated => false).or(where(:deprecated => nil))
  end

  def display_type
    if respond_to?(:volume_template?)
      _("Volume")
    elsif respond_to?(:volume_snapshot_template?)
      _("Volume Snapshot")
    elsif respond_to?(:image?)
      image? ? _("Image") : _("Snapshot")
    else
      _("N/A")
    end
  end

  def display_operating_system
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    else
      operating_system.try(:product_name)
    end
  end

  def display_platform
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    else
      platform
    end
  end

  def display_cpu_cores
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    else
      cpu_total_cores
    end
  end

  def display_memory
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    else
      mem_cpu.to_i * 1024 * 1024
    end
  end

  def display_snapshots
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    else
      v_total_snapshots
    end
  end

  def display_tenant
    respond_to?(:cloud_tenant) ? cloud_tenant.try(:name) : _("N/A")
  end

  def display_deprecated
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    elsif respond_to?(:deprecated)
      _(deprecated.to_s)
    else
      _("N/A")
    end
  end
end
