module MigrationSpecHelper
  module DSL
    def migration_context(direction, &block)
      context "##{direction}", :migrations => direction do
        before(:all) do
          prepare_migrate
        end

        around do |example|
          clearing_caches(&example)
        end

        it("with empty tables") { migrate }

        instance_eval(&block)
      end
    end
  end

  def prepare_migrate
    case migration_direction
    when :up;   migrate_to previous_migration_version
    when :down; migrate_to this_migration_version
    end
  end

  def migrate(options = {})
    clearing_caches do
      if options[:verbose]
        migrate_under_test
      else
        suppress_migration_messages { migrate_under_test }
      end
    end
  end

  def migration_stub(klass)
    stub = ar_stubs.detect { |stub| stub.name.split("::").last == klass.to_s }
    raise NameError, "uninitialized constant #{klass} under #{described_class}" if stub.nil?
    stub
  end

  private

  # Clears any cached column information on stubs, since the migrations
  # themselves will not expect anything to be cached.
  def clear_caches
    ar_stubs.each do |s|
      # inheritance_column changes done by migrations (e.g. to disable STI) are
      # lost on reset_column_information, so we need to restore those changes.
      i = s.inheritance_column

      s.reset_column_information

      s.inheritance_column = i
    end
  end

  def clearing_caches
    clear_caches
    yield
  ensure
    clear_caches
  end

  def ar_stubs
    described_class
      .constants
      .collect { |c| described_class.const_get(c) }
      .select  { |c| c.respond_to?(:ancestors) && c.ancestors.include?(ActiveRecord::Base) }
  end

  def migrate_under_test
    described_class.migrate(migration_direction)
  end

  def migration_direction
    direction = self.class.metadata[:migrations]
    raise "Example must be tagged with :migrations => :up or :migrations => :down" unless direction.in?([:up, :down])
    direction
  end

  def suppress_migration_messages
    save, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    yield
  ensure
    ActiveRecord::Migration.verbose = save
  end

  def migrate_to(version)
    suppress_migration_messages { ActiveRecord::Migrator.migrate('db/migrate', version) }
  end

  def this_migration_version
    migrations, i = migrations_and_index
    migrations[i].version
  end

  def previous_migration_version
    migrations, i = migrations_and_index
    return 0 if i == 0
    migrations[i - 1].version
  end

  def migrations_and_index
    name = described_class.name.underscore
    migrations = ActiveRecord::Migrator.migrations('db/migrate')
    i = migrations.index { |m| m.filename.ends_with? "#{name}.rb" }
    raise "Unknown migration for #{described_class}" if i.nil?
    return migrations, i
  end
end
