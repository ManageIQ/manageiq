class MiqExpression::Component::Before < MiqExpression::Component::Leaf
  def to_arel(timezone)
    target.lt(MiqExpression::RelativeDatetime.normalize(value, timezone, "beginning", target.date?))
  end
end
