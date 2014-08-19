require "spec_helper"

describe VMDB::Config do
  let(:password) { "password" }
  let(:enc_pass) { MiqPassword.encrypt(password) }

  it ".load_config_file" do
    IO.stub(:read => "---\r\nsmtp:\r\n  password: #{enc_pass}\r\n")
    File.stub(:exists?).with("test.yml").and_return(true)
    described_class.load_config_file("test.yml").should == {:smtp => {:password => password}}
  end

  it ".get_file" do
    server        = EvmSpecHelper.create_guid_miq_server_zone[1]
    config        = VMDB::Config.new("vmdb")
    config.config = {:log_depot => {:uri => "smb://server/share", :username => "user", :password => password}}
    config.save

    VMDB::Config.get_file("vmdb").should eq(
      "---\nlog_depot:\n  uri: smb://server/share\n  username: user\n  password: #{enc_pass}\n"
    )
  end

  context "#save" do
    it "to the database" do
      EvmSpecHelper.create_guid_miq_server_zone
      config = VMDB::Config.new("vmdb")
      config.config = {:one => {:two => :three}}
      config.should_receive(:save_file)
      config.save
      Configuration.count.should == 1
      Configuration.first.should have_attributes(:typ => 'vmdb', :settings => {:one => {:two => :three}})
    end
  end

  context "load_and_validate_raw_contents" do
    it "normal" do
      validated, result = VMDB::Config.load_and_validate_raw_contents("vmdb", "---\n'a':\n  'b': 1\n")
      expect(validated).to eql(true)
      expect(result).to be_kind_of(VMDB::Config)
    end

    it "catches syntax errors" do
      validated, result = VMDB::Config.load_and_validate_raw_contents("vmdb", "---\n'a':\n  'b':1\n")
      expect(validated).to eql(false)
      error = result.first
      expect(error[0]).to eql(:contents)
      expect(error[1]).to match(/\AFile contents are malformed/)
    end
  end

  context ".http_proxy_uri" do
    it "without config settings" do
      VMDB::Config.any_instance.stub(:config => {})
      VMDB::Config.http_proxy_uri.should be_nil
    end

    it "without a host" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {}})
      VMDB::Config.http_proxy_uri.should be_nil
    end

    it "with host" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:host => "1.2.3.4", :port => nil, :user => nil, :password => nil}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "http", :host => "1.2.3.4")
    end

    it "with host, port" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:host => "1.2.3.4", :port => 4321, :user => nil, :password => nil}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "http", :host => "1.2.3.4", :port => 4321)
    end

    it "with host, port, user" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:host => "1.2.3.4", :port => 4321, :user => "testuser", :password => nil}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "http", :host => "1.2.3.4", :port => 4321, :userinfo => "testuser")
    end

    it "with host, port, user, password" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:host => "1.2.3.4", :port => 4321, :user => "testuser", :password => "secret"}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "http", :host => "1.2.3.4", :port => 4321, :userinfo => "testuser:secret")
    end

    it "with user missing" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:host => "1.2.3.4", :port => 4321, :user => nil, :password => "secret"}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "http", :host => "1.2.3.4", :port => 4321)
    end

    it "with scheme overridden" do
      VMDB::Config.any_instance.stub(:config => {:http_proxy => {:scheme => "https", :host => "1.2.3.4", :port => 4321, :user => "testuser", :password => "secret"}})
      VMDB::Config.http_proxy_uri.should == URI::Generic.build(:scheme => "https", :host => "1.2.3.4", :port => 4321, :userinfo => "testuser:secret")
    end
  end
end
