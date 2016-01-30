require 'db/MiqBdb/MiqBdb'
require "#{__dir__}/test_files"

describe MiqBerkeleyDB::MiqBdb do
  it "#new" do
    expect { described_class.new(MiqBdb::TestFiles::RPM_PROVIDE_VERSION).close }.not_to raise_error
  end

  it "#pages" do
    bdb = described_class.new(MiqBdb::TestFiles::RPM_PROVIDE_VERSION)

    nkeys = 0

    bdb.pages do |page|
      page.keys do |_key|
        nkeys += 1
      end
    end

    expect(nkeys).to eq(657)

    bdb.close
  end

  context "Hash Database" do
    it "validates" do
      bdb = described_class.new(MiqBdb::TestFiles::RPM_PACKAGES)
      expect(bdb.db).to be_kind_of(MiqBerkeleyDB::MiqBdbHashDatabase)

      # Assert that the number of keys in header is what was extracted
      expect(bdb.db.nkeys).to eq(bdb.size)

      bdb.close
    end
  end
end
