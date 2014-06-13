module VmdbTable::Seeding
  extend ActiveSupport::Concern

  def seed_indexes
    mine   = self.vmdb_indexes.index_by(&:name)
    actual = self.sql_indexes.sort_by(&:name)

    actual.each do |index|
      index_name   = index.name
      index_record = mine.delete(index_name)
      VmdbIndex.seed_for_table(self, index_record || index_name)
    end

    mine.each do |name, i|
      $log.info("MIQ(VmdbTable#seed_indexes) Index <#{name}> for Table <#{self.name}> is no longer in Database <#{self.vmdb_database.name}> - deleting")
      i.destroy
    end
  end
end
