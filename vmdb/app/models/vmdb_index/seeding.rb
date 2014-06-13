module VmdbIndex::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed_for_table(table, index)
      unless index.kind_of?(self)
        $log.info("MIQ(VmdbTableIndex.seed_for_table) Creating <#{index}> for Table <#{table.name}> in Database <#{table.vmdb_database.name}>")
        index = table.vmdb_indexes.create(:name => index)
      end
    end
  end
end
