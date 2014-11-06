class ResourceAction < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  belongs_to :dialog

  serialize  :ae_attributes, Hash

  def automate_queue_hash(override_values = nil, override_attrs = nil)
    override_values ||= {}
    override_attrs  ||= {}
    {
      :namespace        => self.ae_namespace,
      :class_name       => self.ae_class,
      :instance_name    => self.ae_instance,
      :automate_message => self.ae_message,
      :attrs            => (self.ae_attributes || {}).merge(override_attrs),
    }.merge(override_values)
  end

  def fqname=(value)
    self.ae_namespace, self.ae_class, self.ae_instance, attr_name = MiqAeEngine::MiqAePath.split(value)
  end

  def fqname
    MiqAeEngine::MiqAePath.new(
      :ae_namespace => self.ae_namespace,
      :ae_class     => self.ae_class,
      :ae_instance  => self.ae_instance).to_s
  end
  alias ae_path fqname

  def ae_uri
    uri = self.ae_path
    unless self.ae_attributes.blank?
      uri << "?"
      uri << MiqAeEngine::MiqAeUri.hash2query(self.ae_attributes)
    end
    unless self.ae_message.blank?
      uri << "#"
      uri << self.ae_message
    end
    uri
  end

  def deliver_to_automate_from_dialog(dialog_hash_values, target)
    log_header = "MIQ(#{self.class.name}.deliver_to_automate_from_dialog)"
    $log.info("#{log_header} Queuing <#{self.class.name}:#{self.id}> for <#{self.resource_type}:#{self.resource_id}>")
    zone = target.respond_to?(:my_zone) ? target.my_zone : nil
    MiqAeEngine.deliver_queue(prepare_automate_args(dialog_hash_values, target),
                              :zone     => zone,
                              :priority => MiqQueue::HIGH_PRIORITY,
                              :task_id  => "#{self.class.name.underscore}_#{id}")
  end

  def deliver_to_automate_from_dialog_field(dialog_hash_values, target)
    log_header = "MIQ(#{self.class.name}.deliver_to_automate_from_dialog_field)"
    $log.info("#{log_header} Running <#{self.class.name}:#{self.id}> for <#{self.resource_type}:#{self.resource_id}>")

    MiqAeEngine.deliver(prepare_automate_args(dialog_hash_values, target))
  end

  def prepare_automate_args(dialog_hash_values, target)
    automate_values = target.nil? ? {} : {:object_type => target.class.name, :object_id => target.id}
    automate_attrs  = dialog_hash_values[:dialog]

    args = self.automate_queue_hash(automate_values, automate_attrs)
    args[:user_id] ||= User.current_user.try(:id)
    args
  end
end
