class CustomAttribute < ApplicationRecord
  ALLOWED_API_VALUE_TYPES = %w(DateTime Time Date).freeze
  belongs_to :resource, :polymorphic => true
  serialize :serialized_value

  def stored_on_provider?
    source == "VC"
  end
end
