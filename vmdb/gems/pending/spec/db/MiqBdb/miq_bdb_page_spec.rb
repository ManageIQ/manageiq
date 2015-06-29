require "spec_helper"

require 'db/MiqBdb/MiqBdb'
require "#{__dir__}/test_files"

describe MiqBerkeleyDB::MiqBdbPage do

  before do
    bdb = MiqBerkeleyDB::MiqBdb.new(MiqBdb::TestFiles::RPM_PROVIDE_VERSION)
    bdb.pages { |p| @page = p }
  end

  it "#dump" do
    @page.dump.should == <<-DUMP
Page 1
  type:            btree internal
  prev:            0
  next:            0
  log seq num:     file=0  offset=1
  level:           2
  entries:         9
  offset:          3936
  data size:       4070
  data:            f4 0f 98 0f cc 0f ac 0f 60 0f e0 0f 74 0f bc 0f 88 0f a4 07 ...

DUMP
  end

end
