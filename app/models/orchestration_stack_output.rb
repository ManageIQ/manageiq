class OrchestrationStackOutput < ApplicationRecord
  belongs_to :stack, :class_name => "OrchestrationStack"

  alias_attribute :name, :key

  default_value_for :value_type, "string"
  validates :value_type, :inclusion => {:in => %w[string integer float object array boolean datetime time null]}

  def parsed_value
    return nil if value.nil?

    case value_type
    when "string"
      value
    when "integer"
      ActiveRecord::Type::Integer.new.cast(value)
    when "float"
      ActiveRecord::Type::Float.new.cast(value)
    when "object", "array"
      JSON.parse(value)
    when "boolean"
      ActiveRecord::Type::Boolean.new.cast(value)
    when "datetime"
      ActiveRecord::Type::DateTime.new.cast(value)
    when "time"
      ActiveRecord::Type::Time.new.cast(value)
    when "null"
      nil
    end
  end
end
