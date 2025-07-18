class ContainerVolume < ApplicationRecord
  include CustomActionsMixin
  acts_as_miq_taggable
  belongs_to :parent, :polymorphic => true
  belongs_to :persistent_volume_claim, :dependent => :destroy
  attr_accessor :pvc_name, :volume_name

  def self.display_name(number = 1)
    n_('Container Volume', 'Container Volumes', number)
  end

  def attach_volume_queue(userid, vm, pvc_name, volume_name = nil)
    Rails.logger.info("attach_volume_queue started #{pvc_name} to VM [#{vm}] for user #{userid}")
    task_opts = {
      :action => "Attaching PVC #{pvc_name} to VM [#{vm}] for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'attach_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => vm.ext_management_system.queue_name_for_ems_operations,
      :zone        => vm.ext_management_system.my_zone,
      :args        => [vm, pvc_name, volume_name]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def attach_volume(vm, pvc_name, volume_name)
    vm.raw_attach_volume(vm, pvc_name, volume_name)
  end

  def raw_attach_volume(vm, pvc_name, volume_name)
    raise NotImplementedError, _("VM has no EMS, unable to attach volume") unless vm.ext_management_system
  end

  def create_pvc_queue(userid, vm, volume_name, volume_size)
    Rails.logger.info("attach_volume_queue started #{volume_name} to VM [#{vm}] for user #{userid}")
    task_opts = {
      :action => "Attaching PVC #{volume_name} to VM [#{vm}] for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_pvc_and_attach',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => vm.ext_management_system.queue_name_for_ems_operations,
      :zone        => vm.ext_management_system.my_zone,
      :args        => [vm, volume_name, volume_size]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def create_pvc_and_attach(vm, volume_name, volume_size)
    vm.create_pvc(vm, volume_name, volume_size)
  end

  def create_pvc(vm, volume_name,volume_size)
    raise NotImplementedError, _("VM has no EMS, unable to attach volume") unless vm.ext_management_system
  end

  def detach_volume_queue(userid, vm, volume_name) 
    task_opts = {
      :action => "detaching Infra Volume for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'detach_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => vm.ext_management_system.queue_name_for_ems_operations,
      :zone        => vm.ext_management_system.my_zone,
      :args        => [vm, volume_name]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def detach_volume(vm, volume_name)
    vm.raw_detach_volume(vm, volume_name)
  end

  def raw_detach_volume(vm, volume_name)
    raise NotImplementedError, _("VM has no EMS, unable to detach volume") unless vm.ext_management_system
  end
end
