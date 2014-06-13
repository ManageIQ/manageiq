require "spec_helper"

require 'db/MiqBdb/MiqBdbUtil'

describe MiqBerkeleyDB::MiqBdbUtil do
  MIQ_BDB_RPM_NAME_FILENAME = File.expand_path(File.join(File.dirname(__FILE__), %w{data rpm Name}))

  it "#getkeys" do
    bdbUtil = described_class.new()
    keys = bdbUtil.getkeys(MIQ_BDB_RPM_NAME_FILENAME)
    keys.size.should == 690
  end

end
