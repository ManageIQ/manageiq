class OrchestrationStackResource < ApplicationRecord
  include ReportableMixin

  belongs_to :stack, :class_name => "OrchestrationStack"
  include ReportableMixin
end
