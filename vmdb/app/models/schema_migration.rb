class SchemaMigration < ActiveRecord::Base
  def self.db_migration_list
    @db_migration_list ||= SchemaMigration.all.collect { |s| s.version.to_i }.sort
  end

  def self.file_migration_list
    @file_migration_list ||= Dir.glob(Rails.root.join("db", "migrate", "*.rb")).collect do |f|
      File.basename(f).split("_")[0].to_i
    end.sort
  end

  def self.missing_db_migrations
    file_migration_list - db_migration_list
  end

  def self.missing_file_migrations
    # Ignore migrations prior to the collapsed initial migration
    db_migration_list.reject { |m| m < initial_migration } - file_migration_list
  end

  def self.schema_version
    db_migration_list.last
  end

  def self.initial_migration
    file_migration_list.first
  end

  def self.latest_migration
    file_migration_list.last
  end
end
