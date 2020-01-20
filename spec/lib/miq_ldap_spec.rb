# encoding: US-ASCII

RSpec.describe MiqLdap do
  before do
    @host     = 'mycompany.com'

    # TODO: Use an actual user so this test actually tests something in the CI server
    @userid   = nil   # Please change locally in your test (e.g. randomuser@mycompany.com)
    @password = nil   # Please change locally in your test

    @auth = {
      :bind_dn  => @userid,
      :bind_pwd => @password,
      :ldapport => 389,
      :ldaphost => @host
    }

    @options = {
      :mode             => 'ldap',
      :basedn           => 'dc=mycompany,dc=com',
      :follow_referrals => true,
      :user_type        => 'userprincipalname',
      :user_suffix      => 'mycompany.com',
      :auth             => @auth
    }
  end

  it "binds with proper credentials" do
    if @userid
      wrong_ip = 'bugz.mycompany.com'

      # TODO: A specific error should be expected here, not just any
      expect { MiqLdap.new(:host => wrong_ip) }.to raise_error
      ldap_right = MiqLdap.new(:host => @host)

      wrong_userid = 'wrong'
      wrong_password = 'something'

      expect(ldap_right.bind(wrong_userid, @password)).to be_falsey
      expect(ldap_right.bind(@userid,      wrong_password)).to be_falsey
      expect(ldap_right.bind(@userid,      @password)).to be_truthy
    end
  end

  let(:users) { %w(rock@mycompany.com smith@mycompany.com will@mycompany.com john@mycompany.com) }

  it "gets user information" do
    if @userid
      ldap = MiqLdap.new(:host => @host, :basedn => 'dc=mycompany,dc=com', :user_type => 'mail')
      ldap.bind(@userid, @password)

      users.sort.each do |u|
        udata = ldap.get_user_info(u)
        next if udata.nil?
        # puts "\nUser Data for #{udata[:display_name]}:"
        udata.sort_by { |k, _v| k.to_s }.each { |k, v| puts "\t#{k}: #{v}" }

        # ruby-net-ldap adds singleton methods to String/Array object it creates
        # which can lead to 'singleton can't be dumped'  errors
        expect { Marshal.dump(udata) }.not_to raise_error
      end
    end
  end

  it "follows referrals" do
    if @userid
      ldap = MiqLdap.new(@options)
      ldap.bind(@userid, @password)

      user = ldap.get_user_object("newuser@demodomain.mycompany.com")
      # puts "XXX: User=[#{user.inspect}]"

      unless user.nil?
        memberships = ldap.get_memberships(user)
        # puts "XXX: Memberships=[#{memberships.inspect}]"

        expect { Marshal.dump(memberships) }.not_to raise_error
      end
    end
  end

  it "gets the correct memberships calling get_memberships with and without depth" do
    if @userid
      # $log.level = 0
      ldap = MiqLdap.new(@options)
      ldap.bind(@userid, @password)

      user = ldap.get_user_object("myuserid@mycompany.com")
      unless user.nil?
        memberships = ldap.get_memberships(user)
        expect(memberships.sort).to eq(["Administrators", "All", "Developers", "Developers-DemoVirtualCenter", "Developers-ProductionVirtualCenter", "Developers-Subversion", "Domain Admins", "Domain Users", "EvmGroup-super_administrator", "Remote Desktop Users", "Users", "cap-u-reporting", "dev", "devleads", "poc", "test-vmdb", "uat"])

        memberships = ldap.get_memberships(user, 1)
        expect(memberships.sort).to eq(["All", "Developers", "Developers-Subversion", "Domain Admins", "EvmGroup-super_administrator", "cap-u-reporting", "dev", "devleads", "test-vmdb"])

        memberships = ldap.get_memberships(user, 2)
        expect(memberships.sort).to eq(["All", "Developers", "Developers-DemoVirtualCenter", "Developers-ProductionVirtualCenter", "Developers-Subversion", "Domain Admins", "EvmGroup-super_administrator", "Remote Desktop Users", "cap-u-reporting", "dev", "devleads", "poc", "test-vmdb", "uat"])
      end
    end
  end

  it "uses the correct IP Address when multiple hosts are passed" do
    if @userid
      ldap = MiqLdap.new(:host => ["localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("192.168.252.20")
      ldap.bind(@userid, @password)

      ldap = MiqLdap.new(:host => ["192.168.254.15", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("192.168.254.15")
      ldap.bind(@userid, @password)

      ldap = MiqLdap.new(:host => ["dc3.mycompany.com", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("192.168.254.15")
      ldap.bind(@userid, @password)
    end
  end

  context "#using_ldap?" do
    before do
      allow(TCPSocket).to receive(:new)
    end

    it "issues a deprecation warning when using ldap" do
      allow(Settings).to receive(:authentication).and_return(double(:mode =>'ldap'))
      expect($audit_log).to receive(:warn).with(/MiqLdap is a deprecated feature/)

      MiqLdap.using_ldap?
    end

    it "issues no deprecation warning when not using ldap" do
      allow(Settings).to receive(:authentication).and_return(double(:mode =>'database'))
      expect($audit_log).to_not receive(:warn).with(/MiqLdap is a deprecated feature/)

      MiqLdap.using_ldap?
    end
  end

  it "#sid_to_s" do
    data = "\001\005\000\000\000\000\000\005\025\000\000\000+\206\301\364y\307\r\302=\336p\216\237\004\000\000"
    expect(MiqLdap.sid_to_s(data)).to eq("S-1-5-21-4106323499-3255682937-2389761597-1183")
  end

  context 'when a hostname is available' do
    before do
      allow(TCPSocket).to receive(:gethostbyname).and_return(["testhostname", "aliases", "type", "192.168.252.20"])
      allow(TCPSocket).to receive(:new)
    end

    it 'when mode is ldaps returns a hostname and does not set verify_mode' do
      ldap = MiqLdap.new(:mode => "ldaps", :host => ["testhostname", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("testhostname")
      expect(ldap.ldap.instance_variable_get(:@encryption).try(:has_key_path?, :tls_options, :verify_mode)).to be_falsey
    end

    it 'when mode is ldap returns a hostname and does not set encryption options' do
      ldap = MiqLdap.new(:mode => "ldap", :host => ["testhostname", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("testhostname")
      expect(ldap.ldap.instance_variable_get(:@encryption)).to be_nil
    end
  end

  context 'when only an IPAddress is available' do
    before do
      expect(TCPSocket).not_to receive(:gethostbyname)
      allow(TCPSocket).to receive(:new)
    end

    it 'when mode is ldaps returns an IPAddress and disables verify_mode' do
      ldap = MiqLdap.new(:mode => "ldaps", :host => ["192.168.254.15", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("192.168.254.15")
      expect(ldap.ldap.instance_variable_get(:@encryption).fetch_path(:tls_options, :verify_mode)).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'when mode is ldap returns an IPAddress and does not set encryption options' do
      ldap = MiqLdap.new(:mode => "ldap", :host => ["192.168.254.15", "localhost", "dummy", @host])
      expect(ldap.ldap.host).to eq("192.168.254.15")
      expect(ldap.ldap.instance_variable_get(:@encryption)).to be_nil
    end
  end

  context '#get_user_object' do
    before do
      allow(TCPSocket).to receive(:new)
      @opts = {:base => nil, :scope => :sub, :filter => "(userprincipalname=myuserid@mycompany.com)"}
    end

    it "searches for group memberships with the specified group attribute" do
      ldap = MiqLdap.new(:host => ["192.0.2.2"], :group_attribute => "groupMembership")
      @opts[:attributes] = ["*", "groupMembership"]
      expect(ldap).to receive(:search).with(@opts)

      ldap.get_user_object("myuserid@mycompany.com", "upn")
    end

    it "searches for group memberships with the default group attribute" do
      ldap = MiqLdap.new(:host => ["192.0.2.2"])
      @opts[:attributes] = ["*", "memberof"]
      expect(ldap).to receive(:search).with(@opts)

      ldap.get_user_object("myuserid@mycompany.com", "upn")
    end

    it "searches for group membership when username is upn regardless of user_type" do
      ldap = MiqLdap.new(:host => ["192.0.2.2"])
      @opts[:attributes] = ["*", "memberof"]
      expect(ldap).to receive(:search).with(@opts)

      ldap.get_user_object("myuserid@mycompany.com", "bad_user_type")
    end

    it "filters by mail=<user> when user_type is mail" do
      ldap = MiqLdap.new(:host => ["192.0.2.2"])
      @opts[:attributes] = ["*", "memberof"]
      @opts[:filter] = "(mail=myuserid@mycompany.com)"
      expect(ldap).to receive(:search).with(@opts)

      ldap.get_user_object("myuserid@mycompany.com", "mail")
    end
  end

  context "#fqusername" do
    before do
      allow(TCPSocket).to receive(:new)
      @opts = {:host => ["192.0.2.2"], :user_suffix => 'mycompany.com', :domain_prefix => 'my\domain'}
    end

    it "returns username when username is already a dn" do
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("cn=myuser,ou=people,ou=prod,dc=example,dc=com")).to eq("cn=myuser,ou=people,ou=prod,dc=example,dc=com")
    end

    it "returns username when username is a dn with an @ in the dn" do
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("cn=my@user,ou=people,ou=prod,dc=example,dc=com")).to eq("cn=my@user,ou=people,ou=prod,dc=example,dc=com")
    end

    it "returns a constructed dn when user type is a dn" do
      @opts[:user_type] = 'dn'
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("myuser")).to eq("cn=myuser,mycompany.com")
    end

    it "returns username when username is already a upn" do
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("myuserid@mycompany.com")).to eq("myuserid@mycompany.com")
    end

    it "returns username when username is already a domain username" do
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername('my\domain\myuserid')).to eq('my\domain\myuserid')
    end

    it "returns username when username is already a upn even if user_type is samaccountname" do
      @opts[:user_type]   = 'samaccountname'
      @opts[:user_suffix] = 'not_mycompany.com'
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("myuserid@mycompany.com")).to eq("myuserid@mycompany.com")
    end

    it "returns upn when user_type is upn" do
      @opts[:user_type]   = 'userprincipalname'
      @opts[:user_suffix] = 'mycompany.com'
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername("myuserid")).to eq("myuserid@mycompany.com")
    end

    it "returns samaccountname when user_type is samaccountname" do
      @opts[:user_type] = 'samaccountname'
      ldap = MiqLdap.new(@opts)
      expect(ldap.fqusername('myuserid')).to eq('my\domain\myuserid')
    end

    it "searches for username when user_type is mail even when username is UPN" do
      @opts[:user_type] = 'mail'
      ldap = MiqLdap.new(@opts)
      expect(User).to receive(:lookup_by_email)
      expect(User).to receive(:lookup_by_userid)
      expect(ldap.fqusername('myuserid@mycompany.com')).to eq('myuserid@mycompany.com')
    end
  end
end
