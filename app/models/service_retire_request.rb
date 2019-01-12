class ServiceRetireRequest < MiqRetireRequest
  TASK_DESCRIPTION  = 'Service Retire'.freeze
  SOURCE_CLASS_NAME = 'Service'.freeze
  ACTIVE_STATES     = %w(retired) + base_class::ACTIVE_STATES

  delegate :service_template, :to => :source, :allow_nil => true
end
