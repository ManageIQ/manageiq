module VmdbTableEvm::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed_for_database(db, evm_table)
      unless evm_table.kind_of?(self)
        _log.info("Creating <#{evm_table}> in Database <#{db.name}>")
        evm_table = db.evm_tables.create(:name => evm_table)
      end

      evm_table.seed
    end
  end

  def seed
    seed_texts
    seed_indexes
  end

  def seed_texts
    mine   = text_tables.index_by(&:name)
    actual = self.class.connection.respond_to?(:text_tables) ? self.class.connection.text_tables(name) : []

    actual.sort.each do |table_name|
      table = mine.delete(table_name)
      VmdbTableText.seed_for_table(self, table || table_name)
    end

    mine.each do |name, t|
      _log.info("Text Table <#{name}> for Table <#{self.name}> is no longer in Database <#{vmdb_database.name}> - deleting")
      t.destroy
    end
  end
end
