class OperatingSystemFlavorScript < ActiveRecord::Base
  belongs_to :operating_system_flavor
  belongs_to :customization_script
end
