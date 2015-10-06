def require_migration
  spec_name = caller_locations.first.path
  migration_name = spec_name.sub("spec/migrations", "db/migrate").sub("_spec.rb", ".rb")

  require migration_name
end
