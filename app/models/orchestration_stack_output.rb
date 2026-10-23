class OrchestrationStackOutput < ApplicationRecord
  include TypeCastMixin

  belongs_to :stack, :class_name => "OrchestrationStack"

  alias_attribute :name, :key

  default_value_for :value_type, "string"
  validates :value_type, :inclusion => {:in => %w[string integer float object array boolean datetime time null]}

  def parsed_value
    cast_to_type(value_type, value)
  end
end
