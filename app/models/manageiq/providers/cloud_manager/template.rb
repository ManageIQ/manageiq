class ManageIQ::Providers::CloudManager::Template < ::MiqTemplate
  default_value_for :cloud, true

  virtual_column :image?, :type => :boolean

  def image?
    genealogy_parent.nil?
  end

  def snapshot?
    !genealogy_parent.nil?
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system.class::Template
  end

  # Create a cloud image as a queued task and return the task id. The queue
  # name and the queue zone are derived from the provided EMS instance. The EMS
  # instance and a userid are mandatory. Any +options+ are forwarded as
  # arguments to the +create_image+ method.
  #
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
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
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

  # Update a cloud template as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  #
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
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
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

  # Delete a cloud template as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  #
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
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
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

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
