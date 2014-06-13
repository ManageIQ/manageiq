require "spec_helper"

describe MiqLdap do

  before(:each) do
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

      lambda{ ldap_wrong = MiqLdap.new(:host => wrong_ip) }.should raise_error
      ldap_right = MiqLdap.new(:host => @host)

      wrong_userid = 'wrong'
      wrong_password = 'something'

      ldap_right.bind(wrong_userid, @password).should be_false
      ldap_right.bind(@userid,      wrong_password).should be_false
      ldap_right.bind(@userid,      @password).should be_true
    end
  end

  USERS = [
    'rock@mycompany.com',
    'smith@mycompany.com',
    'will@mycompany.com',
    'john@mycompany.com',
  ]
  it "gets user information" do
    if @userid
      ldap = MiqLdap.new(:host => @host, :basedn => 'dc=mycompany,dc=com', :user_type => 'mail')
      ldap.bind(@userid, @password)

      USERS.sort.each do |u|
        udata = ldap.get_user_info(u)
        next if udata.nil?
        # puts "\nUser Data for #{udata[:display_name]}:"
        udata.sort_by { |k,v| k.to_s }.each { |k,v| puts "\t#{k}: #{v}" }

        # ruby-net-ldap adds singleton methods to String/Array object it creates
        # which can lead to 'singleton can't be dumped'  errors
        lambda { Marshal.dump(udata) }.should_not raise_error
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

        lambda { Marshal.dump(memberships) }.should_not raise_error
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
        memberships.sort.should == ["Administrators", "All", "Developers", "Developers-DemoVirtualCenter", "Developers-ProductionVirtualCenter", "Developers-Subversion", "Domain Admins", "Domain Users", "EvmGroup-super_administrator", "Remote Desktop Users", "Users", "cap-u-reporting", "dev", "devleads", "poc", "test-vmdb", "uat"]

        memberships = ldap.get_memberships(user, 1)
        memberships.sort.should == ["All", "Developers", "Developers-Subversion", "Domain Admins", "EvmGroup-super_administrator", "cap-u-reporting", "dev", "devleads", "test-vmdb"]

        memberships = ldap.get_memberships(user, 2)
        memberships.sort.should == ["All", "Developers", "Developers-DemoVirtualCenter", "Developers-ProductionVirtualCenter", "Developers-Subversion", "Domain Admins", "EvmGroup-super_administrator", "Remote Desktop Users", "cap-u-reporting", "dev", "devleads", "poc", "test-vmdb", "uat"]
      end
    end
  end

  it "uses the correct IP Address when multiple hosts are passed" do
    if @userid
      ldap = MiqLdap.new(:host=>["localhost", "dummy", @host])
      ldap.ldap.host.should == "192.168.252.20"
      ldap.bind(@userid, @password)

      ldap = MiqLdap.new(:host=>["192.168.254.15", "localhost", "dummy", @host])
      ldap.ldap.host.should == "192.168.254.15"
      ldap.bind(@userid, @password)

      ldap = MiqLdap.new(:host => ["dc3.mycompany.com", "localhost", "dummy", @host])
      ldap.ldap.host.should == "192.168.254.15"
      ldap.bind(@userid, @password)
    end
  end

  it "#sid_to_s" do
    data = "\001\005\000\000\000\000\000\005\025\000\000\000+\206\301\364y\307\r\302=\336p\216\237\004\000\000"
    MiqLdap.sid_to_s(data).should == "S-1-5-21-4106323499-3255682937-2389761597-1183"
  end
end
