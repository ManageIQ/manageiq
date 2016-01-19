require_migration

describe RenameMiqSearchDb do
  let(:search_stub) { migration_stub(:MiqSearch) }

  migration_context :up do
    it "renames known MiqSearch db values" do
      to_be_renamed = described_class::NAME_HASH.keys.collect do |old_db|
        search_stub.create!(:db => old_db)
      end
      to_be_ignored = search_stub.create!(:db => "Vm")

      migrate

      to_be_renamed.zip(described_class::NAME_HASH.values) do |search, new_db|
        expect(search.reload.db).to eq(new_db)
      end
      expect(to_be_ignored.reload.db).to eq("Vm")
    end
  end
end
