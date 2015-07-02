require "spec_helper"

require 'db/MiqBdb/MiqBdb'
require "#{__dir__}/test_files"

describe MiqBerkeleyDB::MiqBdb do

  it "#new" do
    lambda { described_class.new(MiqBdb::TestFiles::RPM_PROVIDE_VERSION).close }.should_not raise_error
  end

  it "#pages" do
    bdb = described_class.new(MiqBdb::TestFiles::RPM_PROVIDE_VERSION)

    nkeys = 0

    bdb.pages do |page|
      page.keys do |key|
        nkeys += 1
      end
    end

    nkeys.should == 657

    bdb.close
  end

  context "Hash Database" do
    it "validates" do
      bdb = described_class.new(MiqBdb::TestFiles::RPM_PACKAGES)
      bdb.db.should be_kind_of(MiqBerkeleyDB::MiqBdbHashDatabase)

      # Assert that the number of keys in header is what was extracted
      bdb.db.nkeys.should == bdb.size

      bdb.close
    end
  end

end
