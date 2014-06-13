module VmdbTableText::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed_for_table(evm_table, text_table)
      unless text_table.kind_of?(self)
        $log.info("MIQ(VmdbTableText.seed_for_table) Creating Text Table <#{text_table}> for EVM Table <#{evm_table.name}> in Database <#{evm_table.vmdb_database.name}>")
        text_table = evm_table.text_tables.create(:name => text_table, :vmdb_database => evm_table.vmdb_database)
      end

      text_table.seed_indexes
    end
  end
end
