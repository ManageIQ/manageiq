class CustomAttribute < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  def stored_on_provider?
    source == "VC"
  end
end
