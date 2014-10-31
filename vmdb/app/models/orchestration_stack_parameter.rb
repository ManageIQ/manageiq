class OrchestrationStackParameter < ActiveRecord::Base
  belongs_to :stack, :class_name => "OrchestrationStack"
end
