module VmdbTable::Seeding
  extend ActiveSupport::Concern

  def seed_indexes
    mine   = vmdb_indexes.index_by(&:name)
    actual = sql_indexes.sort_by(&:name)

    actual.each do |index|
      index_name   = index.name
      index_record = mine.delete(index_name)
      VmdbIndex.seed_for_table(self, index_record || index_name)
    end

    mine.each do |name, i|
      _log.info("Index <#{name}> for Table <#{self.name}> is no longer in Database <#{vmdb_database.name}> - deleting")
      i.destroy
    end
  end
end
