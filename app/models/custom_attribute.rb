class CustomAttribute < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  serialize :serialized_value

  def value=(value)
    self.serialized_value = value
    self[:value] = value
  end

  def stored_on_provider?
    source == "VC"
  end

  def value_type
    serialized_value ? serialized_value.class.to_s.downcase.to_sym : :string
  end
end
