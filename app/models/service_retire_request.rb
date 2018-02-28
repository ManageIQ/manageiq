class ServiceRetireRequest < MiqRetireRequest
  TASK_DESCRIPTION  = 'Service Retire'.freeze
  SOURCE_CLASS_NAME = 'Service'.freeze

  delegate :service_template, :to => :source, :allow_nil => true
end
