class ArbitrationRule < ApplicationRecord
  ALLOWED_CONDITIONS = %w(is is_not).freeze
  ALLOWED_ACTIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze

  validates :condition, :inclusion => { :in => ALLOWED_CONDITIONS }
  validates :action, :inclusion => { :in => ALLOWED_ACTIONS }
  validates :object_attribute, :object_attribute_value, :presence => true
end
