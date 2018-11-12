class ConfigurationScriptSource < ApplicationRecord
  acts_as_miq_taggable

  has_many    :configuration_script_payloads, :dependent => :destroy
  belongs_to  :authentication
  belongs_to  :manager, :class_name => "ExtManagementSystem"

  virtual_total :total_payloads, :configuration_script_payloads

  def self.display_name(number = 1)
    n_('Repository', 'Repositories', number)
  end
end
