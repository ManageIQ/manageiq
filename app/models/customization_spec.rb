class CustomizationSpec < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"

  serialize :spec

  def is_sysprep_spec?
    self[:spec].fetch_path(['identity', 'value']).nil?
  end

  def is_sysprep_file?
    !is_sysprep_spec?
  end
end
