class MiqExpression::Component::From < MiqExpression::Component::Leaf
  def to_arel(timezone)
    start_value = MiqExpression::RelativeDatetime.normalize(value[0], timezone, "beginning", target.date?)
    end_value   = MiqExpression::RelativeDatetime.normalize(value[1], timezone, "end", target.date?)
    target.between(start_value..end_value)
  end
end
