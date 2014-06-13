class AddUpdateRepoNameToMiqDatabase < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :miq_databases, :update_repo_name, :string

    say_with_time("Migrate data from reserved table") do
      MiqDatabase.includes(:reserved_rec).each do |db|
        db.reserved_hash_migrate(:update_repo_name)
      end
    end
  end

  def down
    say_with_time("Migrating update_repo_name to Reserves table") do
      MiqDatabase.includes(:reserved_rec).each do |d|
        d.reserved_hash_set(:update_repo_name, d.update_repo_name)
        d.save!
      end
    end

    remove_column :miq_databases, :update_repo_name
  end
end
