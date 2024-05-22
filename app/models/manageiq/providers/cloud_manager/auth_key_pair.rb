class ManageIQ::Providers::CloudManager::AuthKeyPair < Authentication
  acts_as_miq_taggable
  has_and_belongs_to_many :vms, :join_table => :key_pairs_vms, :foreign_key => :authentication_id
  virtual_belongs_to :ext_management_system, :uses => :resource

  include Operations

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:AuthKeyPair)
  end

  # Create an auth key pair as a queued task and return the task id. The queue
  # name and the queue zone are derived from the provided EMS instance. The EMS
  # instance and a userid are mandatory. Any +options+ are forwarded as
  # arguments to the +create_key_pair+ method.
  #
  def self.create_key_pair_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Auth Key Pair for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'ManageIQ::Providers::CloudManager::AuthKeyPair',
      :method_name => 'create_key_pair',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_key_pair(ems_id, options)
    raise ArgumentError, _("ems cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)

    klass = ext_management_system.class_by_ems(:AuthKeyPair)

    key_pair_opts = klass.raw_create_key_pair(ext_management_system, options)
    klass.create(key_pair_opts.merge(:resource => ext_management_system))
  end

  # Delete an auth key pair as a queued task and return the task id. The queue
  # name and the queue zone are derived from the resource, and a userid is mandatory.
  #
  def delete_key_pair_queue(userid)
    task_opts = {
      :action => "deleting Auth Key Pair for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_key_pair',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => resource.queue_name_for_ems_operations,
      :zone        => resource.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_key_pair
    raw_delete_key_pair
  end

  # Many Authentications are associated with an ems
  # using `try` to handle the ones that are not
  def ext_management_system
    resource.kind_of?(ExtManagementSystem) ? resource : resource.try(:ext_management_system)
  end

  def self.display_name(number = 1)
    n_('Key Pair', 'Key Pairs', number)
  end
end
