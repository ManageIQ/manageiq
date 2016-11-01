require 'util/miq_apache'

describe MiqApache::Conf do
  it "should raise ConfFileNotSpecified for a missing conf file" do
    expect { MiqApache::Conf.new }.to raise_error(MiqApache::ConfFileNotSpecified)
  end

  it "should raise ConfFileNotSpecified for a bogus conf file" do
    expect { MiqApache::Conf.new("foo") }.to raise_error(MiqApache::ConfFileNotFound)
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

  describe "#create_redirects_config" do
    it "sets non root balancer correctly" do
      default_options = {:cluster => 'evmcluster_ws', :redirects => %w(/api)}
      output = MiqApache::Conf.create_redirects_config(default_options).lines.to_a
      expect(output).to include("ProxyPass /api balancer://evmcluster_ws/api\n")
      expect(output).to include("ProxyPassReverse /api balancer://evmcluster_ws/api\n")
      expect(output).not_to include("RewriteCond \%{REQUEST_URI} !^/proxy_pages\n")
    end
    it "sets root balancer correctly" do
      default_options = {:cluster => 'evmcluster_ui', :redirects => %w(/)}
      output = MiqApache::Conf.create_redirects_config(default_options).lines.to_a
      expect(output).to include("RewriteRule ^/ui/service(?!/(assets|images|img|styles|js|fonts|vendor|gettext)) /ui/service/index.html [L]\n")
      expect(output).to include("RewriteCond \%{REQUEST_URI} !^/proxy_pages\n")
      expect(output).to include("RewriteCond \%{REQUEST_URI} !^/saml2\n")
      expect(output).to include("RewriteCond \%{DOCUMENT_ROOT}/\%{REQUEST_FILENAME} !-f\n")
      expect(output).to include("RewriteRule ^/ balancer://evmcluster_ui\%{REQUEST_URI} [P,QSA,L]\n")
      expect(output).to include("ProxyPassReverse / balancer://evmcluster_ui/\n")
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
      expect(@conf.fname).not_to be_nil
    end

    it "instance should return existing conf instance" do
      expect(MiqApache::Conf).to receive(:new).never
      MiqApache::Conf.instance(File.expand_path(File.join(File.dirname(__FILE__), "data", "apache_test1.conf")))
    end

    it "should have valid conf object" do
      expect(@conf).not_to be_nil
    end

    it "should have #{TOTAL_LINES} lines" do
      expect(@conf.line_count).to eq(TOTAL_LINES)
    end

    it "should have #{CONTENT_LINES} lines of real content due to comments" do
      expect(@conf.content_lines.size).to eq(CONTENT_LINES)
    end

    it "should have #{BLOCK_DIRECTIVES} block directives" do
      expect(@conf.block_directives.size).to eq(BLOCK_DIRECTIVES)
    end
  end

  context "with existing proxy_balancer" do
    before(:each) do
      @conf_file = File.expand_path(File.join(File.dirname(__FILE__), "data", "apache_balancer.conf"))
      @conf = MiqApache::Conf.new(@conf_file)
    end

    context "with other protocol than http" do
      it "add_ports should add the port with the given protocol" do
        @conf.add_ports(3000, "ws")
        expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember ws://0.0.0.0:3000\n", "</Proxy>\n"])
      end
    end

    it "add_ports should add the first port line" do
      @conf.add_ports(3000, "http")
      expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"])
    end

    it "add_ports should add the first two port lines" do
      @conf.add_ports([3000, 3001], "http")
      expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"])
    end

    it "add_ports should add a single port line to existing lines" do
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.add_ports(3002, "http")
      expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3002\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"])
    end

    it "remove_ports should do nothing with no BalancerMember lines" do
      before = @conf.raw_lines.dup
      @conf.remove_ports(3000, "http")
      expect(@conf.raw_lines).to eq(before)
    end

    it "remove_ports should remove the only port line" do
      before = @conf.raw_lines.dup
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"]
      @conf.remove_ports(3000, "http")
      expect(@conf.raw_lines).to eq(before)
    end

    it "remove_ports should remove the only two port lines" do
      before = @conf.raw_lines.dup
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.remove_ports([3000, 3001], "http")
      expect(@conf.raw_lines).to eq(before)
    end

    it "remove_ports should remove one port line, leaving one" do
      @conf.raw_lines = ["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "BalancerMember http://0.0.0.0:3001\n", "</Proxy>\n"]
      @conf.remove_ports(3001, "http")
      expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"])
    end

    it "#save" do
      allow(MiqApache::Control).to receive(:config_ok?).and_return(true)
      backup = "#{@conf_file}_old"
      FileUtils.cp(@conf_file, backup)
      begin
        @conf.add_ports(3000, "http")
        expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"])
        @conf.save

        @conf.reload
        expect(@conf.raw_lines).to eq(["<Proxy balancer://evmcluster/ lbmethod=byrequests>\n", "BalancerMember http://0.0.0.0:3000\n", "</Proxy>\n"])
      ensure
        FileUtils.mv(backup, @conf_file)
      end
    end
  end

  context ".create_conf_file" do
    it "with existing file should raise error" do
      allow(File).to receive_messages(:exist? => true)
      expect { described_class.create_conf_file("xxx", []) }.to raise_error(MiqApache::ConfFileAlreadyExists)
    end

    it "with proper args should generate a config file" do
      conf_file  = "xxx"
      content_in = [
        "## CFME SSL Virtual Host Context",
        "",
        {:directive      => "VirtualHost",
         :attribute      => "*:443",
         :configurations => [
           "ProxyPreserveHost on",
           "RequestHeader set X_FORWARDED_PROTO 'https'",
           "ErrorLog /var/log/apache/ssl_error.log",
           "SSLEngine on",
           {:directive      => "Directory",
            :attribute      => "\"/var/www/cgi-bin\"",
            :configurations => [
              "Options +Indexes",
              "Order allow,deny",
              "Allow from all",
            ]
           },
           {:directive      => "something",
            :configurations => "My test"
           }
         ]
        }
      ]
      expected_output = <<EOF
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
      allow(File).to receive_messages(:exist? => false)
      allow(FileUtils).to receive(:touch)
      allow(File).to receive_messages(:file? => true)
      allow(File).to receive_messages(:read => "")
      allow(FileUtils).to receive(:cp)
      expect(File).to receive(:write).with(conf_file, expected_output)
      allow(MiqApache::Control).to receive_messages(:config_ok? => true)
      expect(described_class.create_conf_file(conf_file, content_in)).to be_truthy
    end

    it "with proper args should generate a config file" do
      conf_file  = "xxx"
      content_in = [
        "## CFME SSL Virtual Host Context",
        "",
        {:attribute      => "*:443",
         :configurations => ["ProxyPreserveHost on"]
        },
      ]

      allow(File).to receive_messages(:exist? => false)
      allow(FileUtils).to receive(:touch)
      allow(File).to receive_messages(:file? => true)
      allow(File).to receive_messages(:read => "")
      expect { described_class.create_conf_file(conf_file, content_in) }.to raise_error(ArgumentError, ":directive key is required")
    end
  end
end
