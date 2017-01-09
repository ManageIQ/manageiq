class MiqExpression::Component::Base
  def self.build
    raise "Called abtract method: .build"
  end

  def to_sql(timezone)
    to_arel(timezone).to_sql
  end

  def to_arel(_timezone)
    raise "Called abstract method: #to_arel"
  end
end
