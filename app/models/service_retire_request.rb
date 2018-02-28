class ServiceRetireRequest < MiqRequest
  TASK_DESCRIPTION  = 'Service Retire'.freeze
  SOURCE_CLASS_NAME = 'Service'.freeze

  validates :request_state, :inclusion => { :in => %w(pending finished) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished" }

  validate :must_have_user
  delegate :service_template, :to => :source, :allow_nil => true

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME

  def my_role
    'ems_operations'
  end

  def my_zone
  end
end
