class ArbitrationRule < ApplicationRecord
  ALLOWED_OPERATIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze
  validates :operation, :inclusion => { :in => ALLOWED_OPERATIONS }
  validates :name, :expression, :presence => true

  serialize :expression

  def self.get_by_rule_class(rule_class)
    where('expression like ?', "%#{rule_class}%").order(:priority)
  end
end
