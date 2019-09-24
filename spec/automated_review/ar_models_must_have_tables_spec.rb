describe "ApplicationRecord backed models must be backed by a table" do
  (ApplicationRecord.descendants - [MiqRegionRemote, VmdbDatabaseConnection, VmdbDatabaseLock]).each do |model|
    it("#{model} has a table") { expect(model.table_exists?).to be(true) }
  end
end
