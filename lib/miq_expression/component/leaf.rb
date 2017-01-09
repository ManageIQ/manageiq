class MiqExpression::Component::Leaf < MiqExpression::Component::Base
  def self.build(options)
    value = if MiqExpression::Field.is_field?(options["value"])
              MiqExpression::Field.parse(options["value"]).arel_attribute
            else
              options["value"]
            end
    new(MiqExpression::Field.parse(options["field"]), value)
  end

  attr_reader :target, :value

  def initialize(target, value)
    @target = target
    @value = value
  end
end
