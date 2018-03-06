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

  def self.create_image_queue(userid, ext_management_system, options = {})
    queue_opts = {
      :class_name  => 'ManageIQ::Providers::Openstack::CloudManager::Template',
      :method_name => 'create_image',
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
