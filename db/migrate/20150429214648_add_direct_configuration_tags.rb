class AddDirectConfigurationTags < ActiveRecord::Migration
  def change
    create_table :direct_configuration_profiles_configuration_tags, :id => false do |t|
      t.belongs_to :configuration_profile, :type => :bigint
      t.belongs_to :configuration_tag, :type => :bigint
    end

    add_index :configuration_profiles_configuration_tags, :configuration_profile_id,
              :name => :index_direct_configuration_profiles_tags_profile_id
    add_index :configuration_profiles_configuration_tags, :configuration_tag_id,
              :name => :index_direct_configuration_profiles_tags_tag_id

    create_table :direct_configuration_tags_configured_systems, :id => false do |t|
      t.belongs_to :configured_system, :type => :bigint
      t.belongs_to :configuration_tag, :type => :bigint
    end
    add_index :direct_configuration_tags_configured_systems, :configured_system_id,
              :name => :index_direct_configured_systems_tags_system_id
    add_index :direct_configuration_tags_configured_systems, :configuration_tag_id,
              :name => :index_direct_configured_systems_tag_tag_id
  end
end
