class ResourceAction < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :configuration_template, :polymorphic => true
  belongs_to :dialog
  belongs_to :workflow

  serialize  :ae_attributes, Hash

  PROVISION   = 'Provision'.freeze
  RETIREMENT  = 'Retirement'.freeze
  RECONFIGURE = 'Reconfigure'.freeze

  validate :ensure_workflow_or_automate

  def ensure_workflow_or_automate
    return if workflow_id.nil? || (ae_namespace.nil? && ae_class.nil? && ae_instance.nil?)

    errors.add(:workflow_id, N_("Cannot have workflow_id and ae_namespace, ae_class, and ae_instance present"))
  end

  def readonly?
    return true if super
    resource.readonly? if resource.kind_of?(ServiceTemplate)
  end

  def automate_queue_hash(target, override_attrs, user, open_url_task_id = nil)
    if target.nil?
      override_values = {}
    elsif target.kind_of?(Hash)
      override_values = target
    elsif target.kind_of?(Array) || target.kind_of?(ActiveRecord::Relation)
      klass = target.first.id.class
      object_ids = target.collect { |t| "#{klass}::#{t.id}" }.join(",")
      override_attrs = {:target_object_type        => target.first.class.base_class.name,
                        'Array::target_object_ids' => object_ids}.merge(override_attrs || {})
      override_values = {}
    else
      override_values = {:object_type => target.class.base_class.name, :object_id => target.id}
    end

    attrs = (ae_attributes || {}).merge(override_attrs || {})

    {
      :namespace        => ae_namespace,
      :class_name       => ae_class,
      :instance_name    => ae_instance,
      :automate_message => ae_message,
      :open_url_task_id => open_url_task_id,
      :attrs            => attrs,
    }.merge(override_values).tap do |args|
      args[:user_id] ||= user.id
      args[:miq_group_id] ||= user.current_group.id
      args[:tenant_id] ||= user.current_tenant.id
      args[:username] ||= user.userid
    end
  end

  def fqname=(value)
    self.ae_namespace, self.ae_class, self.ae_instance, _attr_name = MiqAeEngine::MiqAePath.split(value)
  end

  def fqname
    MiqAeEngine::MiqAePath.new(
      :ae_namespace => ae_namespace,
      :ae_class     => ae_class,
      :ae_instance  => ae_instance).to_s
  end
  alias_method :ae_path, :fqname

  def ae_uri
    uri = ae_path
    unless ae_attributes.blank?
      uri << "?"
      uri << MiqAeEngine::MiqAeUri.hash2query(ae_attributes)
    end
    unless ae_message.blank?
      uri << "#"
      uri << ae_message
    end
    uri
  end

  def deliver_queue(dialog_hash_values, target, user, task_id = nil)
    _log.info("Queuing <#{self.class.name}:#{id}> for <#{resource_type}:#{resource_id}>")
    if workflow
      args = {:object_type => target.class.name, :object_id => target.id}
      queue_opts = {:zone => target.try(:my_zone)}

      workflow.execute(:userid => user.userid, :inputs => dialog_hash_values, :queue_opts => queue_opts, :args => args)
    else
      MiqAeEngine.deliver_queue(automate_queue_hash(target, dialog_hash_values[:dialog], user, task_id),
                                :zone     => target.try(:my_zone),
                                :priority => MiqQueue::HIGH_PRIORITY,
                                :task_id  => "#{self.class.name.underscore}_#{id}")
    end
  end

  def deliver_task(dialog_hash_values, target, user)
    task = MiqTask.create(:name => "Automate method task for open_url", :userid => user.userid)
    deliver_queue(dialog_hash_values, target, user, task.id)
    task.update_status(MiqTask::STATE_QUEUED, MiqTask::STATUS_OK, 'MiqTask has been queued.')
    task.id
  end

  def deliver(dialog_hash_values, target, user)
    _log.info("Running <#{self.class.name}:#{id}> for <#{resource_type}:#{resource_id}>")

    if workflow
      task = MiqTask.wait_for_taskid(deliver_queue(dialog_hash_values, target, user))
      workflow_instances = WorkflowInstance.find(task.context_data[:workflow_instance_id])
      workflow_instances.output
    else
      workflow = MiqAeEngine.deliver(automate_queue_hash(target, dialog_hash_values[:dialog], user))
      workflow.root.attributes
    end
  end
end
