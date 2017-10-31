class ContainerVolume < ApplicationRecord
  include CustomActionsMixin
  acts_as_miq_taggable
  belongs_to :parent, :polymorphic => true
  belongs_to :persistent_volume_claim, :dependent => :destroy

  def generic_custom_buttons
    CustomButton.buttons_for("ContainerVolume")
  end
end
