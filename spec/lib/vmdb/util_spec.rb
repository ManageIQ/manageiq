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
end
