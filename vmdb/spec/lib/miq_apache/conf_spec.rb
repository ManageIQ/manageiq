require "spec_helper"

describe MiqApache::Conf do
  it "should raise ConfFileNotSpecified for a missing conf file" do
    lambda { MiqApache::Conf.new }.should raise_error(MiqApache::ConfFileNotSpecified)
  end

  it "should raise ConfFileNotSpecified for a bogus conf file" do
    lambda { MiqApache::Conf.new("foo") }.should raise_error(MiqApache::ConfFileNotFound)
  end

  context "building balancer config" do
    context "lbmethod" do
      it "should return a config with lbmethod of 'byrequests' by default" do
        expect(MiqApache::Conf.create_balancer_config).to include("lbmethod=byrequests")
      end

      it "should return a config with lbmethod of 'bytraffic' if passed :traffic" do
        expect(MiqApache::Conf.create_balancer_config(:lbmethod => :traffic)).to include("lbmethod=bytraffic")
      end

      it "should return a config with lbmethod of 'bybusyness' if passed :busy" do
        expect(MiqApache::Conf.create_balancer_config(:lbmethod => :busy)).to include("lbmethod=bybusyness")
      end
    end

    it "should set cluster name" do
      expect(MiqApache::Conf.create_balancer_config(:cluster => 'evmcluster_ui')).to include("Proxy balancer://evmcluster_ui/")
    end
  end

  context "building redirects config" do
    before do
      @default_options = {:cluster => 'evmcluster_ui', :redirects => ['/miqservices/', '/']}
    end

    it "sets balancer correctly" do
      output = MiqApache::Conf.create_redirects_config(@default_options).lines.to_a
      expect(output).to include("ProxyPass /miqservices/ balancer://evmcluster_ui/miqservices/\n")
      expect(output).to include("ProxyPassReverse /miqservices/ balancer://evmcluster_ui/miqservices/\n")
      expect(output).to include("ProxyPass / balancer://evmcluster_ui/\n")
      expect(output).to include("ProxyPassReverse / balancer://evmcluster_ui/\n")
    end

    it "should write two lines per redirect" do
      output = MiqApache::Conf.create_redirects_config(@default_options).lines.to_a
      expect(output.length).to be(Array(@default_options[:redirects]).length*2)
    end
  end

  context "with apache_test1.conf" do
    TOTAL_LINES      = 1009
    CONTENT_LINES    = 236
    BLOCK_DIRECTIVES = 13
    before(:each) do
      @conf_file = File.expand_path(File.join(File.dirname(__FILE__), "data", "apache_test1.conf"))
      @conf = MiqApache::Conf.new(@conf_file)
    end

    it "should have fname attribute" do
      @conf.fname.should_not be_nil
    end

    it "instance should return existing conf instance" do
      MiqApache::Conf.should_receive(:new).never
      MiqApache::Conf.instance(File.expand_path(File.join(File.dirname(__FILE__), "data", "apache_test1.conf")))
    end

    it "should have valid conf object" do
      @conf.should_not be_nil
    end

    it "should have #{TOTAL_LINES} lines" do
      @conf.line_count.should == TOTAL_LINES
    end

    it "should have #{CONTENT_LINES} lines of real content due to comments" do
      @conf.content_lines.size.should == CONTENT_LINES
    end

    it "should have #{BLOCK_DIRECTIVES} block directives" do
      @conf.block_directives.size.should == BLOCK_DIRECTIVES
    end
  end

  context "with existing proxy_balancer" do
    before(:each) do
      @conf_file = File.expand_path(File.join(File.dirname(__FILE__), "data", "apache_balancer.conf"))
      @conf = MiqApache::Conf.new(@conf_file)
    end

    it "add_ports should add the first port line" do
      @conf.add_ports(3000)
      @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
    end

    it "add_ports should add the first two port lines" do
      @conf.add_ports([3000, 3001])
      @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
    end

    it "add_ports should add a single port line to existing lines" do
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.add_ports(3002)
      @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3002\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
    end

    it "remove_ports should do nothing with no BalancerMember lines" do
      before = @conf.raw_lines.dup
      @conf.remove_ports(3000)
      @conf.raw_lines.should == before
    end

    it "remove_ports should remove the only port line" do
      before = @conf.raw_lines.dup
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
      @conf.remove_ports(3000)
      @conf.raw_lines.should == before
    end

    it "remove_ports should remove the only two port lines" do
      before = @conf.raw_lines.dup
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.remove_ports([3000,3001])
      @conf.raw_lines.should == before
    end

    it "remove_ports should remove one port line, leaving one" do
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.remove_ports(3001)
      @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
    end

    it "#save" do
      MiqApache::Control.stub(:config_ok?).and_return(true)
      backup = "#{@conf_file}_old"
      FileUtils.cp(@conf_file, backup)
      begin
        @conf.add_ports(3000)
        @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
        @conf.save

        @conf.reload
        @conf.raw_lines.should == ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
      ensure
        FileUtils.mv(backup, @conf_file)
      end
    end
  end

  context ".create_conf_file" do
    it "with existing file should raise error" do
      File.stub(:exists? => true)
      expect { described_class.create_conf_file("xxx", []) }.to raise_error(MiqApache::ConfFileAlreadyExists)
    end

    it "with proper args should generate a config file" do
      conf_file  = "xxx"
      content_in = [
        "## CFME SSL Virtual Host Context",
        "",
        { :directive => "VirtualHost",
          :attribute => "*:443",
          :configurations => [
            "ProxyPreserveHost on",
            "RequestHeader set X_FORWARDED_PROTO 'https'",
            "ErrorLog /var/log/apache/ssl_error.log",
            "SSLEngine on",
            { :directive => "Directory",
              :attribute => "\"/var/www/cgi-bin\"",
              :configurations => [
                "Options +Indexes",
                "Order allow,deny",
                "Allow from all",
              ]
            },
            { :directive => "something",
              :configurations => "My test"
            }
          ]
        }
      ]
      expected_output =<<EOF
## CFME SSL Virtual Host Context


<VirtualHost *:443>
ProxyPreserveHost on
RequestHeader set X_FORWARDED_PROTO 'https'
ErrorLog /var/log/apache/ssl_error.log
SSLEngine on

<Directory "/var/www/cgi-bin">
Options +Indexes
Order allow,deny
Allow from all
</Directory>


<something>
My test
</something>

</VirtualHost>
EOF
      File.stub(:exists? => false)
      FileUtils.stub(:touch)
      File.stub(:file? => true)
      File.stub(:read => "")
      FileUtils.stub(:cp)
      File.should_receive(:write).with(conf_file, expected_output)
      MiqApache::Control.stub(:config_ok? => true)
      expect(described_class.create_conf_file(conf_file, content_in)).to be_true
    end

    it "with proper args should generate a config file" do
      conf_file  = "xxx"
      content_in = [
        "## CFME SSL Virtual Host Context",
        "",
        { :attribute => "*:443",
          :configurations => ["ProxyPreserveHost on"]
        },
      ]

      File.stub(:exists? => false)
      FileUtils.stub(:touch)
      File.stub(:file? => true)
      File.stub(:read => "")
      expect { described_class.create_conf_file(conf_file, content_in) }.to raise_error(ArgumentError, ":directive key is required")
    end
  end
end
