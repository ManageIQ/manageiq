class ManageIQ::Providers::CloudManager::AuthKeyPair < ::AuthPrivateKey
  include AvailabilityMixin

  acts_as_miq_taggable
  has_and_belongs_to_many :vms, :join_table => :key_pairs_vms, :foreign_key => :authentication_id

  include_concern 'Operations'

  def self.class_by_ems(ext_management_system)
    ext_management_system.class::AuthKeyPair
  end

  def self.create_key_pair_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Auth Key Pair for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => "ManageIQ::Providers::CloudManager::AuthKeyPair",
      :method_name => 'create_key_pair',
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_key_pair(ems_id, options)
    raise ArgumentError, _("ems cannot be nil") if ems_id.nil?
    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ems cannot be found") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    # TODO(maufart): add cloud_tenant to database table?
    created_key_pair = klass.raw_create_key_pair(ext_management_system, options)
    klass.create(
      :name        => created_key_pair.name,
      :fingerprint => created_key_pair.fingerprint,
      :resource    => ext_management_system
    )
  end

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
      :zone        => resource.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_key_pair
    raw_delete_key_pair
  end
end
