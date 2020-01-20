RSpec.describe VMDB::Util do
  context ".http_proxy_uri" do
    it "without config settings" do
      stub_settings(:http_proxy => { :default => {} })
      expect(described_class.http_proxy_uri).to be_nil
    end

    it "returns proxy for old settings" do
      stub_settings_merge(:http_proxy => {:host => "1.2.3.4", :port => nil, :user => nil, :password => nil})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4"))
    end

    it "without a host" do
      stub_settings_merge(:http_proxy => {:default => {}})
      expect(described_class.http_proxy_uri).to be_nil
    end

    it "with a blank host" do
      # We couldn't save nil http_proxy host, so some host values will be ''
      stub_settings_merge(:http_proxy => {:default => {:host => ''}})
      expect(described_class.http_proxy_uri).to be_nil
    end

    it "with host" do
      stub_settings_merge(:http_proxy => {:default => {:host => "1.2.3.4", :port => nil, :user => nil, :password => nil}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4"))
    end

    it "with host, port" do
      stub_settings_merge(:http_proxy => {:default => {:host => "1.2.3.4", :port => 4321, :user => nil, :password => nil}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4",
                                                                      :port   => 4321))
    end

    it "with host, port, user" do
      stub_settings_merge(:http_proxy => {:default => {:host     => "1.2.3.4", :port => 4321, :user => "testuser",
                                                 :password => nil}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4",
                                                                      :port   => 4321, :userinfo => "testuser"))
    end

    it "with host, port, user, password" do
      stub_settings_merge(:http_proxy => {:default => {:host => "1.2.3.4", :port => 4321,
                                                 :user => "testuser", :password => "secret"}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4",
                                                                      :port => 4321, :userinfo => "testuser:secret"))
    end

    it "with user missing" do
      stub_settings_merge(:http_proxy => {:default => {:host => "1.2.3.4", :port => 4321,
                                                 :user => nil, :password => "secret"}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "http", :host => "1.2.3.4",
                                                                      :port => 4321))
    end

    it "with unescaped user value" do
      password = "secret#"
      config = {:http_proxy => {:default => {:host => "1.2.3.4", :port => 4321,
                                             :user => "testuser", :password => password}}}
      stub_settings_merge(config)
      userinfo = "testuser:secret%23"
      uri_parts = {:scheme => "http", :host => "1.2.3.4", :port => 4321, :userinfo => userinfo}
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(uri_parts))
    end

    it "with scheme overridden" do
      stub_settings_merge(:http_proxy => {:default => {:scheme => "https", :host => "1.2.3.4", :port => 4321,
                                                 :user => "testuser", :password => "secret"}})
      expect(described_class.http_proxy_uri).to eq(URI::Generic.build(:scheme => "https", :host => "1.2.3.4",
                                                                      :port   => 4321, :userinfo => "testuser:secret"))
    end
  end

  context ".log_duration" do
    shared_examples_for "log_duration timestamps" do |file_content, type|
      it "#{file_content.lines.count} lines, #{type == :normal_case ? 'normal case' : 'no leading timestamps'}" do
        filename = "abc.log"
        string1 = StringIO.new(file_content)
        string2 = StringIO.new(file_content)

        allow(File).to receive(:open).with(filename, "r").and_yield(string1)
        require 'elif'
        allow(Elif).to receive(:open).and_yield(string2)

        if type == :normal_case || file_content.lines.count <= 250
          start_time, end_time = described_class.log_duration(filename)
          expect(start_time).to be_kind_of(Time)
          expect(end_time).to   be_kind_of(Time)
        else
          expect(described_class.log_duration(filename)).to eq([nil, nil])
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
      allow(Rails).to receive(:root).and_return(Pathname.new("/var/www/miq/vmdb"))
    end

    def self.assert_zip_entry_from_path(expected_entry, path)
      it "#{path} => #{expected_entry}" do
        expect(described_class.send(:zip_entry_from_path, path)).to eq(expected_entry)
      end
    end

    assert_zip_entry_from_path("ROOT/var/log/messages.log", "/var/log/messages.log")
    assert_zip_entry_from_path("log/evm.log", "/var/www/miq/vmdb/log/evm.log")
    assert_zip_entry_from_path("ROOT/www/var/vmdb/miq/log/something.log", "/www/var/vmdb/miq/log/something.log")
    assert_zip_entry_from_path("log/apache/ssl_access.log", "/var/www/miq/vmdb/log/apache/ssl_access.log")
    assert_zip_entry_from_path("config/database.yml", "/var/www/miq/vmdb/config/database.yml")
    assert_zip_entry_from_path("GUID", "/var/www/miq/vmdb/GUID")
  end

  context ".add_zip_entry(private)" do
    require 'zip/filesystem'

    let(:origin_file) { Tempfile.new 'origin' }
    let(:symlink_level_1) { create_temp_symlink 'symlink_level_1', origin_file.path }
    let(:symlink_level_2) { create_temp_symlink 'symlink_level_2', symlink_level_1 }
    let(:mtime) { origin_file.mtime }
    let(:ztime) { Zip::DOSTime.at(mtime.to_i) }
    let(:zip) { double }
    let(:zip_file) { double }

    it "entry is a normal file" do
      file  = "/var/log/messages.log"
      entry = "ROOT/var/log/messages.log"
      log_mtime = Time.zone.parse("2013-09-24 09:00:45 -0400")
      expect(File).to receive(:mtime).with(file).and_return(log_mtime)
      expect(described_class).to receive(:zip_entry_from_path).with(file).and_return(entry)

      log_ztime = Zip::DOSTime.at(log_mtime.to_i)
      zip_entry = Zip::Entry.new(zip, entry, nil, nil, nil, nil, nil, nil, log_ztime)
      expect(zip).to receive(:add).with(zip_entry, file)

      expect(File).to receive(:size).and_return(1) # a stub size for _log.info
      expect(described_class.send(:add_zip_entry, zip, file, zip_file)).to eq([entry, log_mtime])
    end

    it "entry is a symlink to origin file, origin file is added with symlink's name" do
      entry = 'ROOT' + symlink_level_1
      zip_entry = Zip::Entry.new(zip, entry, nil, nil, nil, nil, nil, nil, ztime)
      expect(zip).to receive(:add).with(zip_entry, File.realpath(origin_file.path))
      expect(described_class.send(:add_zip_entry, zip, symlink_level_1, zip_file)).to eq([entry, mtime])
    end

    it "entry is a symlink to symlink to origin file, origin file is added with symlink's name" do
      entry = 'ROOT' + symlink_level_2
      zip_entry = Zip::Entry.new(zip, entry, nil, nil, nil, nil, nil, nil, ztime)
      expect(zip).to receive(:add).with(zip_entry, File.realpath(origin_file.path))
      expect(described_class.send(:add_zip_entry, zip, symlink_level_2, zip_file)).to eq([entry, mtime])
    end

    after do
      origin_file.close
      origin_file.unlink
    end
  end

  it ".get_evm_log_for_date" do
    log_files = ["log/rhevm.log", "log/evm.log"]
    allow(Dir).to receive_messages(:glob => log_files)

    expect(described_class.get_evm_log_for_date("log/*.log")).to eq("log/evm.log")
  end

  private

  def create_temp_symlink(name, origin)
    symlink_file = Tempfile.new name
    symlink_file.close
    symlink_name = symlink_file.path
    symlink_file.unlink
    FileUtils.ln_s origin, symlink_name
    symlink_name
  end
end
