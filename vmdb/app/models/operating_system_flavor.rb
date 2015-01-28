class OperatingSystemFlavor < ActiveRecord::Base
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :provisioning_manager

  has_and_belongs_to_many :customization_scripts
end
