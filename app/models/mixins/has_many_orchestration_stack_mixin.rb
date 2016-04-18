module HasManyOrchestrationStackMixin
  extend ActiveSupport::Concern

  included do
    has_many :orchestration_stacks,
             :foreign_key => :ems_id,
             :dependent   => :destroy

    has_many :orchestration_stacks_resources,
             :through => :orchestration_stacks,
             :source  => :resources

    has_many :direct_orchestration_stacks,
             -> { where(:ancestry => nil) },
             :foreign_key => :ems_id,
             :class_name  => "OrchestrationStack"
  end
end
