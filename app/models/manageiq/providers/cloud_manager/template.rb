class ManageIQ::Providers::CloudManager::Template < ::MiqTemplate
  default_value_for :cloud, true

  virtual_column :image?, :type => :boolean

  def image?
    genealogy_parent.nil?
  end

  def snapshot?
    !genealogy_parent.nil?
  end

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Amazon::CloudManager::Template
                            ManageIQ::Providers::Openstack::CloudManager::Template
                            ManageIQ::Providers::Azure::CloudManager::Template
                            ManageIQ::Providers::Google::CloudManager::Template
                            ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate
                            ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate))
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system.class::Template
  end

  def self.create_image_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "Creating Cloud Template for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.name,
      :method_name => 'create_image',
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.raw_create_image(_ext_management_system, _options = {})
    raise NotImplementedError, "raw_create_image must be implemented in a subclass"
  end

  def validate_create_image(_ext_management_system, _options = {})
    validate_unsupported(_("Create Image Operation"))
  end

  def self.create_image(ems_id, options)
    raise ArgumentError, _("ems cannot be nil") if ems_id.nil?
    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ems cannot be found") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    klass.raw_create_image(ext_management_system, options)
  end

  def update_image_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Template for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_image',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_image(options = {})
    raw_update_image(options)
  end

  def validate_update_image
    validate_unsupported("Update Image Operation")
  end

  def raw_update_image(_options = {})
    raise NotImplementedError, _("raw_update_image must be implemented in a subclass")
  end

  def delete_image_queue(userid)
    task_opts = {
      :action => "Deleting Cloud Template for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_image',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_image
    raise NotImplementedError, _("raw_delete_image must be implemented in a subclass")
  end

  def validate_delete_image
    validate_unsupported(_("Delete Cloud Template Operation"))
  end

  def delete_image
    raw_delete_image
  end

  def validate_unsupported(message_prefix)
    {:available => false,
     :message   => _("%{message} is not available for %{name}.") % {:message => message_prefix, :name => name}}
  end

  def self.display_name(number = 1)
    n_('Image', 'Images', number)
  end

  def self.tenant_id_clause(user_or_group)
    template_tenant_ids = MiqTemplate.accessible_tenant_ids(user_or_group, Rbac.accessible_tenant_ids_strategy(self))
    tenant = user_or_group.current_tenant

    if tenant.source_id
      ["(vms.template = true AND (vms.tenant_id = (?) AND vms.publicly_available = false OR vms.publicly_available = true))", tenant.id]
    else
      ["(vms.template = true AND (vms.tenant_id IN (?) OR vms.publicly_available = true))", template_tenant_ids] unless template_tenant_ids.empty?
    end
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
