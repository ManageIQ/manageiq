class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :parent, :class_name => 'ConfigurationProfileForeman'
  belongs_to :operating_system_flavor

  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  has_and_belongs_to_many :raw_configuration_tags,
                          :join_table  => 'configuration_profiles_configuration_tags',
                          :class_name  => 'ConfigurationTag',
                          :foreign_key => :configuration_profile_id

  def configuration_tags
    tag_hash.values
  end

  def tag_hash
    tag_hash = raw_configuration_tags.index_by(&:class)
    parent ? tag_hash.reverse_merge(parent.tag_hash) : tag_hash
  end
end
