class CustomAttribute < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  serialize :serialized_value

  def stored_on_provider?
    source == "VC"
  end
end
