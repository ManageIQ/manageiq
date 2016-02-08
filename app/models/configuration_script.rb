class ConfigurationScript < ActiveRecord::Base
  belongs_to :configuration_manager, :class_name => 'ManageIQ::Providers::ConfigurationManager'
end
