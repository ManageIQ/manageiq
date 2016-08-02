class ArbitrationRule < ApplicationRecord
  ALLOWED_OPERATIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze
  validates :operation, :inclusion => { :in => ALLOWED_OPERATIONS }
  validates :name, :expression, :presence => true

  serialize :expression
end
