class AddHyperthreadingToHosts < ActiveRecord::Migration
  class Host < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :hosts, :hyperthreading, :boolean

    say_with_time("Migrate data from reserved table") do
      Host.includes(:reserved_rec).each do |h|
        h.reserved_hash_migrate(:hyperthreading)
      end
    end
  end

  def down
    remove_column :hosts, :hyperthreading
  end
end
