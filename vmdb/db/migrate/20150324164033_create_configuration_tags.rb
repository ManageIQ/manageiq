class CreateConfigurationTags < ActiveRecord::Migration
  def change
    create_table :configuration_tags do |t|
      t.string :type
      t.string :manager_ref
      t.string :name
      t.belongs_to :manager, :type => :bigint

      t.timestamps
    end

    create_table :configuration_profiles_configuration_tags, :id => false do |t|
      t.belongs_to :configuration_profile, :type => :bigint
      t.belongs_to :configuration_tag, :type => :bigint
    end

    add_index :configuration_profiles_configuration_tags, :configuration_profile_id,
              :name => :configuration_profiles_configuration_tags_profile_id
    add_index :configuration_profiles_configuration_tags, :configuration_tag_id,
              :name => :configuration_profiles_configuration_tags_tag_id

    create_table :configuration_tags_configured_systems, :id => false do |t|
      t.belongs_to :configured_system, :type => :bigint
      t.belongs_to :configuration_tag, :type => :bigint
    end
    add_index :configuration_tags_configured_systems, :configured_system_id,
              :name => :configured_systems_configuration_system_id
    add_index :configuration_tags_configured_systems, :configuration_tag_id,
              :name => :configured_systems_configuration_tag_id
  end
end
