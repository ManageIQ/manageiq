class SchemaMigration < ActiveRecord::Base
  def self.up_to_date?
    begin
      migrations = missing_db_migrations
      files      = missing_file_migrations
      db_ver     = schema_version
    rescue => err
      return [false, err]
    end

    return [false, "database schema is not up to date.  Schema version is [#{db_ver}].  Missing migrations: [#{migrations.join(", ")}]",
      "database should be migrated to the latest version"] unless migrations.empty?
    return [false, "database schema is from a newer version of the product and may be incompatible.  Schema version is [#{db_ver}].  Missing files: [#{files.join(", ")}]",
      "appliance should be updated to match database version"] unless files.empty?

    return [true, "database schema version #{db_ver} is up to date"]
  end

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
