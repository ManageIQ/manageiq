class CustomizationScriptRef < ActiveRecord::Base
  belongs_to :ref, :polymorphic => true
  belongs_to :customization_script
end
