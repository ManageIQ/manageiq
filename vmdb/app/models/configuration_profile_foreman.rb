class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :parent, :class_name => 'ConfigurationProfileForeman'
  belongs_to :operating_system_flavor

  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  has_and_belongs_to_many :configuration_tags,
                          :join_table  => 'configuration_profiles_configuration_tags',
                          :foreign_key => :configuration_profile_id

  def all_tags
    tag_hash = configuration_tags.index_by(&:class)
    parent ? tag_hash.reverse_merge(parent.all_tags) : tag_hash
  end
end
