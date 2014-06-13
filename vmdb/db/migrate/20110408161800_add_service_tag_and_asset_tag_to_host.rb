class AddServiceTagAndAssetTagToHost < ActiveRecord::Migration
  class Host < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :hosts, :service_tag, :string
    add_column :hosts, :asset_tag,   :string

    say_with_time("Migrate data from reserved table") do
      Host.includes(:reserved_rec).each do |h|
        h.reserved_hash_migrate(:service_tag, :asset_tag)
      end
    end
  end

  def self.down
    remove_column :hosts, :service_tag
    remove_column :hosts, :asset_tag
  end
end
