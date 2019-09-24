class OrchestrationStackOutput < ApplicationRecord
  belongs_to :stack, :class_name => "OrchestrationStack"

  alias_attribute :name, :key
end
