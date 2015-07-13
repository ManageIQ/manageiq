class FixIndexOnRelationships < ActiveRecord::Migration
  #
  # Fixes index naming issue in migration 20100908214807_recreate_relationships
  #
  # The down is empty because removing the index will be taken care of in that
  # migration.
  #

  def self.up
    old_rails_level, Rails.logger.level = Rails.logger.level, Logger::ERROR # Temporarily disable warning logging since the index may not exist
    old_miq_level, $log.level = $log.level, Logger::FATAL                   # Temporarily disable error logging since the index may not exist
    remove_index(:relationships, [:resource_type, :resource_id, :relationship]) rescue nil
    add_index(:relationships, [:resource_type, :resource_id, :relationship], :name => "index_relationships_on_resource_and_relationship") rescue nil
    Rails.logger.level = old_rails_level
    $log.level = old_miq_level
  end

  def self.down
  end
end
