class AddFailoverToHosts < ActiveRecord::Migration
  class Host < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :hosts, :failover, :boolean

    say_with_time("Migrate data from reserved table") do
      Host.includes(:reserved_rec).each do |e|
        e.reserved_hash_migrate(:failover)
      end
    end
  end

  def self.down
    remove_column :hosts, :failover
  end
end
