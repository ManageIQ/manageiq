class ConfigurationLocation < ActiveRecord::Base
  belongs_to :provisioning_manager
  belongs_to :parent, :class_name => 'ConfigurationLocation'

  alias_attribute :display_name, :title
end
