class ManageIQ::Providers::CloudManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :orchestration_template
  belongs_to :cloud_tenant

  def self.create_stack(orchestration_manager, stack_name, template, options = {})
    klass = orchestration_stack_class_factory(orchestration_manager, template)
    ems_ref = klass.raw_create_stack(orchestration_manager,
                                     stack_name,
                                     template,
                                     options)
    tenant = CloudTenant.find_by(:name => options[:tenant_name], :ems_id => orchestration_manager.id)

    klass.create(:name                   => stack_name,
                 :ems_ref                => ems_ref,
                 :status                 => 'CREATE_IN_PROGRESS',
                 :resource_group         => options[:resource_group],
                 :ext_management_system  => orchestration_manager,
                 :cloud_tenant           => tenant,
                 :orchestration_template => template)
  end

  def self.orchestration_stack_class_factory(orchestration_manager, template)
    "#{orchestration_manager.class.name}::#{template.stack_type}".constantize
  end

  def self.display_name(number = 1)
    n_('Orchestration Stack', 'Orchestration Stacks', number)
  end
end
