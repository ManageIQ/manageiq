class MiqExpression::Component::Contains < MiqExpression::Component::Leaf
  def self.build(options)
    target = if options["tag"]
               MiqExpression::Tag.parse(options["tag"])
             else
               MiqExpression::Field.parse(options["field"])
             end
    new(target, options["value"])
  end

  def to_arel(_timezone)
    target.contains(value)
  end
end
