require "spec_helper"

require 'db/MiqBdb/MiqBdbUtil'
require "#{__dir__}/test_files"

describe MiqBerkeleyDB::MiqBdbUtil do

  it "#getkeys" do
    bdbUtil = described_class.new()
    keys = bdbUtil.getkeys(MiqBdb::TestFiles::RPM_NAME)
    keys.size.should == 690
  end

end
