class ConfiguredSystemScripts < ActiveRecord::Base
  belongs_to :configured_system
  belongs_to :customization_script
end
