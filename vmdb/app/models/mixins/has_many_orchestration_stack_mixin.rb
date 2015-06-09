module HasManyOrchestrationStackMixin
  extend ActiveSupport::Concern

  included do
    has_many :orchestration_stacks,
             :foreign_key => :ems_id,
             :dependent   => :destroy

    has_many :direct_orchestration_stacks,
             :foreign_key => :ems_id,
             :conditions  => OrchestrationStack.arel_table[:ancestry].eq(nil).to_sql,
             :class_name  => "OrchestrationStack"
  end
end
