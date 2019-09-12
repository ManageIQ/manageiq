class ManageIQ::Providers::ContainerManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::ContainerManager"
  belongs_to :container_template, :foreign_key => :orchestration_template_id, :class_name => "ContainerTemplate"

  def self.create_stack(container_template, params, project_name)
    new(:name                  => container_template.name,
        :ext_management_system => container_template.ext_management_system,
        :container_template    => container_template).tap do |stack|
      stack.send(:add_provider_objects, raw_create_stack(container_template, params, project_name))
      stack.save!
    end
  end

  def self.raw_create_stack(container_template, params, project_name)
    container_template.instantiate(params, project_name)
  rescue => err
    _log.error("Failed to provision from container template [#{container_template.name}], error: [#{err}]")
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def self.status_class
    "#{name}::Status".constantize
  end

  def retire_now(requester = nil)
    update(:retirement_requester => requester)
    finish_retirement
  end

  def raw_status
    failed = resources.any? { |obj| obj.resource_status == 'failed' }
    if failed
      update(:status => 'failed')
      return self.class.status_class.new('failed', nil)
    end

    done = resources.all? do |obj|
      miq_class = obj.resource_category
      miq_obj = miq_class.constantize.find_by(:ems_ref => obj.ems_ref) if miq_class
      obj.update(:resource_status => 'succeeded') if miq_obj
      miq_class.nil? || miq_obj
    end

    update(:status => 'succeeded') if done
    message = done ? "completed" : "in progress"

    self.class.status_class.new(message, nil)
  end

  def add_provider_objects(objects)
    self.resources = objects.collect { |object| add_provider_object(object) }
  end
  private :add_provider_objects

  def add_provider_object(object)
    options = {
      :name              => object[:metadata][:name],
      :physical_resource => object[:metadata][:namespace],
      :ems_ref           => object[:metadata][:uid],
      :start_time        => object[:metadata][:creationTimestamp],
      :logical_resource  => object[:kind],
      :resource_category => object[:miq_class],
      :description       => object[:apiVersion],
      :resource_status   => 'creating'
    }
    options[:resource_status] = 'failed' if object[:kind].blank?
    OrchestrationStackResource.new(options)
  end
  private :add_provider_object
end
