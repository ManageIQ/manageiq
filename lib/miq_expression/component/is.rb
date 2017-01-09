class MiqExpression::Component::Is < MiqExpression::Component::Leaf
  def to_arel(timezone)
    start_val = MiqExpression::RelativeDatetime.normalize(value, timezone, "beginning", target.date?)
    end_val = MiqExpression::RelativeDatetime.normalize(value, timezone, "end", target.date?)

    if !target.date? || MiqExpressionRelativeDatetime.relative?(value)
      target.between(start_val..end_val)
    else
      target.eq(start_val)
    end
  end
end
