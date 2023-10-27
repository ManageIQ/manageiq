class MiqTemplate < VmOrTemplate
  include CustomActionsMixin

  default_scope { where(:template => true) }

  supports_not :kickstart_provisioning

  virtual_column :display_type,                         :type => :string
  virtual_column :display_operating_system,             :type => :string
  virtual_column :display_platform,                     :type => :string
  virtual_column :display_tenant,                       :type => :string
  virtual_column :display_deprecated,                   :type => :string
  virtual_column :display_memory,                       :type => :integer

  include_concern 'Operations'

  def self.base_model
    MiqTemplate
  end

  def self.corresponding_model
    module_parent::Vm
  end
  class << self; alias_method :corresponding_vm_model, :corresponding_model; end

  delegate :corresponding_model, :to => :class
  alias_method :corresponding_vm_model, :corresponding_model

  def scan_via_ems?
    true
  end

  def self.eligible_for_provisioning
    where(:type => subclasses_supporting(:provisioning).map(&:name)).active
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

  def display_memory
    mem_cpu.to_i * 1024 * 1024
  end

  def display_tenant
    respond_to?(:cloud_tenant) ? cloud_tenant.try(:name) : _("N/A")
  end

  def display_deprecated
    if respond_to?(:volume_template?) || respond_to?(:volume_snapshot_template?)
      _("N/A")
    elsif respond_to?(:deprecated)
      deprecated ? _("true") : _("false")
    else
      _("N/A")
    end
  end

  def memory_for_request(request, flavor_id = nil)
    flavor_id ||= request.get_option(:instance_type)
    flavor_obj = Flavor.find(flavor_id)

    memory = flavor_obj.try(:memory) if request.source.try(:cloud)
    return memory if memory.present?

    request = prov.kind_of?(MiqRequest) ? prov : prov.miq_request
    memory = request.get_option(:vm_memory).to_i
    %w(amazon openstack google).include?(vendor) ? memory : memory.megabytes
  end

  def number_of_cpus_for_request(request, flavor_id = nil)
    flavor_id ||= request.get_option(:instance_type)
    flavor_obj = Flavor.find(flavor_id)

    num_cpus = flavor_obj.try(:cpus) if request.source.try(:cloud)
    return num_cpus if num_cpus.present?

    request = prov.kind_of?(MiqRequest) ? prov : prov.miq_request
    num_cpus = request.get_option(:number_of_sockets).to_i * request.get_option(:cores_per_socket).to_i
    num_cpus.zero? ? request.get_option(:number_of_cpus).to_i : num_cpus
  end

  private_class_method def self.refresh_association
    :miq_templates
  end
end
