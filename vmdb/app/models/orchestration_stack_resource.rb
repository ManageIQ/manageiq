class OrchestrationStackResource < ActiveRecord::Base
  include ReportableMixin

  belongs_to :stack, :class_name => "OrchestrationStack"
end
