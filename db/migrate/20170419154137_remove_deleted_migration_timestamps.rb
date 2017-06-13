class RemoveDeletedMigrationTimestamps < ActiveRecord::Migration[5.0]
  class SchemaMigration < ActiveRecord::Base; end

  DELETED_TIMESTAMPS = [20160106214719, 20160425161345].freeze

  def up
    SchemaMigration.where(:version => DELETED_TIMESTAMPS).delete_all
  end
end
