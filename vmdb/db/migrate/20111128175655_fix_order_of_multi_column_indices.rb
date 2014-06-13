class FixOrderOfMultiColumnIndices < ActiveRecord::Migration
  def self.up
    remove_index :authentications, [:resource_type, :resource_id]
    add_index    :authentications, [:resource_id, :resource_type]

    remove_index :binary_blobs,    [:resource_type, :resource_id]
    add_index    :binary_blobs,    [:resource_id, :resource_type]

    remove_index :ems_events,      [:ems_id, :chain_id]
    add_index    :ems_events,      [:chain_id, :ems_id]

    remove_index :filesystems,     [:resource_type, :resource_id]
    add_index    :filesystems,     [:resource_id, :resource_type]

    remove_index :jobs,            [:agent_class, :agent_id]
    add_index    :jobs,            [:agent_id, :agent_class]

    old_rails_level, Rails.logger.level = Rails.logger.level, Logger::ERROR # Temporarily disable warning logging since the index may not exist
    old_miq_level, $log.level = $log.level, Logger::FATAL                   # Temporarily disable error logging since the index may not exist
    remove_index(:relationships, :name => "index_relationships_on_resource_and_relationship") rescue nil
    remove_index(:relationships,   [:resource_type, :resource_id, :relationship]) rescue nil
    Rails.logger.level = old_rails_level
    $log.level = old_miq_level
    add_index    :relationships,   [:resource_id, :resource_type, :relationship], :name => "index_relationships_on_resource_and_relationship"

    remove_index :states,          [:resource_type, :resource_id]
    add_index    :states,          [:resource_id, :resource_type]

    remove_index :taggings,        [:taggable_type, :taggable_id]
    add_index    :taggings,        [:taggable_id, :taggable_type]
  end

  def self.down
    remove_index :authentications, [:resource_id, :resource_type]
    add_index    :authentications, [:resource_type, :resource_id]

    remove_index :binary_blobs,    [:resource_id, :resource_type]
    add_index    :binary_blobs,    [:resource_type, :resource_id]

    remove_index :ems_events,      [:chain_id, :ems_id]
    add_index    :ems_events,      [:ems_id, :chain_id]

    remove_index :filesystems,     [:resource_id, :resource_type]
    add_index    :filesystems,     [:resource_type, :resource_id]

    remove_index :jobs,            [:agent_id, :agent_class]
    add_index    :jobs,            [:agent_class, :agent_id]

    old_rails_level, Rails.logger.level = Rails.logger.level, Logger::ERROR # Temporarily disable warning logging since the index may not exist
    old_miq_level, $log.level = $log.level, Logger::FATAL                   # Temporarily disable error logging since the index may not exist
    remove_index(:relationships,   :name => "index_relationships_on_resource_and_relationship") rescue nil
    remove_index(:relationships,   [:resource_id, :resource_type, :relationship]) rescue nil
    Rails.logger.level = old_rails_level
    $log.level = old_miq_level
    add_index    :relationships,   [:resource_type, :resource_id, :relationship], :name => "index_relationships_on_resource_and_relationship"

    remove_index :states,          [:resource_id, :resource_type]
    add_index    :states,          [:resource_type, :resource_id]

    remove_index :taggings,        [:taggable_id, :taggable_type]
    add_index    :taggings,        [:taggable_type, :taggable_id]
  end
end
