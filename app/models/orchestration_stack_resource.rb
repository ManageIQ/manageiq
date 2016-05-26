class OrchestrationStackResource < ApplicationRecord
  belongs_to :stack, :class_name => "OrchestrationStack"
end
