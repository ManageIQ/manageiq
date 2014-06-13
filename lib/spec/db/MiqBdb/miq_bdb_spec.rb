require "spec_helper"

require 'db/MiqBdb/MiqBdb'

describe MiqBerkeleyDB::MiqBdb do
  MIQ_BDB_RPM_PROVIDE_VERSION_FILENAME = File.expand_path(File.join(File.dirname(__FILE__), %w{data rpm Provideversion}))
  MIQ_BDB_RPM_PACKAGES_FILENAME        = File.expand_path(File.join(File.dirname(__FILE__), %w{data rpm Packages}))

  it "#new" do
    lambda { described_class.new(MIQ_BDB_RPM_PROVIDE_VERSION_FILENAME).close }.should_not raise_error
  end

  it "#pages" do
    bdb = described_class.new(MIQ_BDB_RPM_PROVIDE_VERSION_FILENAME)

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
      bdb = described_class.new(MIQ_BDB_RPM_PACKAGES_FILENAME)
      bdb.db.should be_kind_of(MiqBerkeleyDB::MiqBdbHashDatabase)

      # Assert that the number of keys in header is what was extracted
      bdb.db.nkeys.should == bdb.size

      bdb.close
    end
  end

end
