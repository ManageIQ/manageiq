class OperatingSystemFlavor < ApplicationRecord
  acts_as_miq_taggable
  belongs_to :provisioning_manager

  has_and_belongs_to_many :customization_scripts
  has_and_belongs_to_many :customization_script_ptables,
                          :join_table              => :customization_scripts_operating_system_flavors,
                          :association_foreign_key => :customization_script_id
  has_and_belongs_to_many :customization_script_media,
                          :join_table              => :customization_scripts_operating_system_flavors,
                          :association_foreign_key => :customization_script_id
end
