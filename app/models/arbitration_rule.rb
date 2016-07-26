class ArbitrationRule < ApplicationRecord
  ALLOWED_ACTIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze
  validates :action, :inclusion => { :in => ALLOWED_ACTIONS }
  validates :name, :expression, :presence => true
end
