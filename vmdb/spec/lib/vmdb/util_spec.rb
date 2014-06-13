require "spec_helper"

describe VMDB::Util do
  context ".log_duration" do
    shared_examples_for "log_duration timestamps" do |file_content, type|
      it "#{file_content.lines.count} lines, #{type == :normal_case ? 'normal case' : 'no leading timestamps'}" do
        filename = "abc.log"
        string1 = StringIO.new(file_content)
        string1.should_receive(:close)
        string2 = StringIO.new(file_content)
        string2.should_receive(:close)

        File.stub(:open).with(filename, "r").and_return(string1)
        require 'elif'
        Elif.stub(:open).and_return(string2)

        if type == :normal_case || file_content.lines.count <= 250
          start_time, end_time = described_class.log_duration(filename)
          start_time.should be_kind_of(Time)
          end_time.should   be_kind_of(Time)
        else
          described_class.log_duration(filename).should == [nil, nil]
        end
      end
    end

    line_with_timestamp    = "[2010-08-06T15:36:54.000749 #62084:3fd3c5833be0]\n"
    line_with_timestamp2   = "[2013-08-06T15:36:54.000749 #62084:3fd3c5833be0]\n"
    line_without_timestamp = "line with no timestamps\n"

    include_examples "log_duration timestamps", (line_with_timestamp * 500) + (line_with_timestamp2 * 500), :normal_case
    include_examples "log_duration timestamps", (line_without_timestamp * 199) + line_with_timestamp
    include_examples "log_duration timestamps", (line_without_timestamp * 249) + line_with_timestamp
    include_examples "log_duration timestamps", (line_without_timestamp * 250) + line_with_timestamp
    include_examples "log_duration timestamps", (line_without_timestamp * 251) + line_with_timestamp
  end

  context ".zip_entry_from_path (private)" do
    before do
      Rails.stub(:root).and_return(Pathname.new("/var/www/miq/vmdb"))
    end

    def self.assert_zip_entry_from_path(expected_entry, path)
      it "#{path} => #{expected_entry}" do
        described_class.zip_entry_from_path(path).should == expected_entry
      end
    end

    assert_zip_entry_from_path("ROOT/var/log/messages.log", "/var/log/messages.log")
    assert_zip_entry_from_path("log/evm.log", "/var/www/miq/vmdb/log/evm.log")
    assert_zip_entry_from_path("ROOT/www/var/vmdb/miq/log/something.log", "/www/var/vmdb/miq/log/something.log")
    assert_zip_entry_from_path("log/apache/ssl_access.log", "/var/www/miq/vmdb/log/apache/ssl_access.log")
    assert_zip_entry_from_path("config/database.yml", "/var/www/miq/vmdb/config/database.yml")
    assert_zip_entry_from_path("ROOT/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_hba.conf", "/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_hba.conf")
    assert_zip_entry_from_path("GUID", "/var/www/miq/vmdb/GUID")
  end

  it ".add_zip_entry" do
    file  = "/var/log/messages.log"
    entry = "ROOT/var/log/messages.log"
    mtime = Time.parse("2013-09-24 09:00:45 -0400")
    File.should_receive(:mtime).with(file).and_return(mtime)
    File.should_receive(:directory?).with(file).and_return(false)
    described_class.should_receive(:zip_entry_from_path).with(file).and_return(entry)

    zip = double
    zip.should_receive(:add).with(entry, file)
    zip_file = double
    zip_file.should_receive(:utime).with(mtime, entry)
    zip.should_receive(:file).and_return(zip_file)

    described_class.add_zip_entry(zip, file).should == [entry, mtime]
  end

  it ".get_evm_log_for_date" do
    log_files = ["log/rhevm.log", "log/evm.log"]
    Dir.stub(:glob => log_files)

    described_class.get_evm_log_for_date("log/*.log").should == "log/evm.log"
  end
end
