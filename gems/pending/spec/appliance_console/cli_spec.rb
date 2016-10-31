require "appliance_console/cli"

describe ApplianceConsole::Cli do
  subject { described_class.new }

  it "should set hostname if defined" do
    expect_any_instance_of(LinuxAdmin::Hosts).to receive(:hostname=).with('host1')
    expect_any_instance_of(LinuxAdmin::Hosts).to receive(:save).and_return(true)
    expect_any_instance_of(LinuxAdmin::Service.new("test").class).to receive(:restart).and_return(true)

    subject.parse(%w(--host host1)).run
  end

  it "should not set hostname if none specified" do
    expect_any_instance_of(LinuxAdmin::Hosts).to_not receive(:hostname=)

    allow(subject).to receive(:create_key) # just give it something to do
    subject.parse(%w(--key)).run
  end

  it "should set database host to localhost if running locally" do
    subject.parse(%w(--internal -r 1 --dbdisk x))
    expect_v2_key
    expect(subject).to receive(:disk_from_string).with('x').and_return('/dev/x')
    expect(subject).to receive(:say)
    expect(ApplianceConsole::InternalDatabaseConfiguration).to receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'root',
            :interactive => false,
            :disk        => '/dev/x')
      .and_return(double(:activate => true, :post_activation => true))
    expect(subject.key_configuration).not_to receive(:activate)
    subject.run
  end

  it "should pass username and password when configuring database locally" do
    subject.parse(%w(--internal --username user --password pass -r 1 --dbdisk x))
    expect_v2_key
    expect(subject).to receive(:disk_from_string).and_return('x')
    expect(subject).to receive(:say)
    expect(ApplianceConsole::InternalDatabaseConfiguration).to receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false,
            :disk        => 'x')
      .and_return(double(:activate => true, :post_activation => true))

    subject.run
  end

  it "should not run post activation if internal database activation fails" do
    subject.parse(%w(--internal --username user --password pass -r 1 --dbdisk x))
    expect_v2_key
    expect(subject).to receive(:disk_from_string).and_return('x')
    expect(subject).to receive(:say).twice
    config_double = double(:activate => false)
    expect(ApplianceConsole::InternalDatabaseConfiguration).to receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false,
            :disk        => 'x')
      .and_return(config_double)
    expect(config_double).not_to receive(:post_activation)

    subject.run
  end

  it "should not run post activation if external database activation fails" do
    subject.parse(%w(--hostname host --dbname db --username user --password pass -r 1))
    expect_v2_key
    expect(subject).to receive(:say).twice
    config_double = double(:activate => false)
    expect(ApplianceConsole::ExternalDatabaseConfiguration).to receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :region      => 1,
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(config_double)
    expect(config_double).not_to receive(:post_activation)

    subject.run
  end

  it "should handle remote databases (and setup region)" do
    subject.parse(%w(--hostname host --dbname db --username user --password pass -r 1))
    expect_v2_key
    expect(subject).to receive(:say)
    expect(ApplianceConsole::ExternalDatabaseConfiguration).to receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :region      => 1,
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(double(:activate => true, :post_activation => true))

    subject.run
  end

  it "should handle remote databases (not setting up region)" do
    subject.parse(%w(--hostname host --dbname db --username user --password pass))
    expect_v2_key
    expect(subject).to receive(:say)
    expect(ApplianceConsole::ExternalDatabaseConfiguration).to receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(double(:activate => true, :post_activation => true))

    subject.run
  end

  context "#ipa" do
    it "should handle uninstalling ipa" do
      expect(subject).to receive(:say)
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:new)
        .and_return(double(:ipa_client_configured? => true, :deactivate => nil))
      subject.parse(%w(--uninstall-ipa)).run
    end

    it "should skip uninstalling ipa if not installed" do
      expect(subject).to receive(:say)
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:new)
        .and_return(double(:ipa_client_configured? => false))
      subject.parse(%w(--uninstall-ipa)).run
    end

    it "should install ipa" do
      expect_any_instance_of(LinuxAdmin::Hosts).to receive(:hostname).and_return('client.domain.com')
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:ipa_client_configured?).and_return(false)
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:new)
        .with('client.domain.com',
              :ipaserver => 'ipa.domain.com',
              :principal => 'admin',
              :domain    => 'domain.com',
              :realm     => 'DOMAIN.COM',
              :password  => 'pass').and_return(double(:activate => true, :post_activation => nil))
      subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass --iparealm DOMAIN.COM --ipadomain domain.com)).run
    end

    it "should not post_activate install ipa (aside: testing passing in host" do
      expect_any_instance_of(LinuxAdmin::Hosts).to receive(:hostname=).with("client.domain.com")
      expect_any_instance_of(LinuxAdmin::Hosts).to receive(:save).and_return(true)
      expect_any_instance_of(LinuxAdmin::Service.new("test").class).to receive(:restart).and_return(true)
      expect_any_instance_of(LinuxAdmin::Hosts).to_not receive(:hostname)
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:ipa_client_configured?).and_return(false)
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:new)
        .with('client.domain.com',
              :ipaserver => 'ipa.domain.com',
              :principal => 'admin',
              :domain    => nil,
              :realm     => nil,
              :password  => 'pass').and_return(double(:activate => false))
      subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass --host client.domain.com)).run
    end

    it "should complain if installing ipa-client when ipa is already installed" do
      expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:ipa_client_configured?).and_return(true)
      expect do
        subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass)).run
      end.to raise_error(/uninstall/)
    end
  end

  context "#install_certs" do
    it "should basic install completed (default ca_name, non verbose)" do
      expect(subject).to receive(:say).with(/creating/)
      expect_any_instance_of(LinuxAdmin::Hosts).to receive(:hostname).and_return('client.domain.com')
      expect(subject).to receive(:say).with(/certificate result/)
      expect(subject).not_to receive(:say).with(/rerun/)
      expect(ApplianceConsole::CertificateAuthority).to receive(:new)
        .with(
          :hostname => "client.domain.com",
          :realm    => nil,
          :ca_name  => "ipa",
          :pgclient => true,
          :pgserver => false,
          :http     => true,
          :verbose  => false,
        ).and_return(double(:activate => true, :status_string => "good", :complete? => true))

      subject.parse(%w(--postgres-client-cert --http-cert)).run
    end

    it "should basic install waiting (manual ca_name, verbose)" do
      expect(subject).to receive(:say).with(/creating/)
      expect_any_instance_of(LinuxAdmin::Hosts).to receive(:hostname).and_return('client.domain.com')
      expect(subject).to receive(:say).with(/certificate result/)
      expect(subject).to receive(:say).with(/rerun/)
      expect(ApplianceConsole::CertificateAuthority).to receive(:new)
        .with(
          :hostname => "client.domain.com",
          :realm    => "realm.domain.com",
          :ca_name  => "super",
          :pgclient => false,
          :pgserver => true,
          :http     => false,
          :verbose  => true,
        ).and_return(double(:activate => true, :status_string => "good", :complete? => false))

      subject.parse(%w(--postgres-server-cert --verbose --ca super --iparealm realm.domain.com)).run
    end
  end

  context "#config_tmp_disk" do
    it "configures disk" do
      expect(subject).to receive(:disk_from_string).with('x').and_return('/dev/x')
      expect(subject).to receive(:say)
      expect(ApplianceConsole::TempStorageConfiguration).to receive(:new)
        .with(:disk      => '/dev/x')
        .and_return(double(:activate => true))

      subject.parse(%w(--tmpdisk x)).run
    end

    it "configures disk with auto" do
      expect(subject).to receive(:disk_from_string).with('auto').and_return('/dev/x')
      expect(subject).to receive(:say)
      expect(ApplianceConsole::TempStorageConfiguration).to receive(:new)
        .with(:disk      => '/dev/x')
        .and_return(double(:activate => true))

      subject.parse(%w(--tmpdisk auto)).run
    end

    it "suggests disk with unknown disk" do
      expect(subject).to receive(:disk_from_string).with('abc').and_return(nil)
      expect(subject).to receive(:disk).and_return(double(:path => 'dev-good'))
      expect(subject).to receive(:say).with(/abc/)
      expect(subject).to receive(:say).with(/dev-good/)
      expect(ApplianceConsole::TempStorageConfiguration).not_to receive(:new)

      subject.parse(%w(--tmpdisk abc)).run
    end

    it "complains when no disks available" do
      expect(subject).to receive(:disk_from_string).with('abc').and_return(nil)
      expect(subject).to receive(:disk).and_return(nil)
      expect(subject).to receive(:say).with(/no disk/)
      expect(ApplianceConsole::TempStorageConfiguration).not_to receive(:new)

      subject.parse(%w(--tmpdisk abc)).run
    end
  end

  # private methods
  # mostly handles by context "#key" and cli_specs focused on internal/external database
  context "parse" do
    context "#hostname and local?" do
      it "should not default" do
        expect(subject.hostname).to be_nil
        expect(subject).not_to be_database
        expect(subject).not_to be_local_database # the main difference between local and local_database
        expect(subject).to be_local
      end

      it "should have 'localhost' for internal databases" do
        subject.parse(%w(--internal --region 1))
        expect(subject.hostname).to eq("localhost")
        expect(subject).to be_database
        expect(subject).to be_local
        expect(subject).to be_local_database
      end

      it "should be local (even if explicitly setting hostname" do
        subject.parse(%w(--hostname localhost --region 1))
        expect(subject).to be_database
        expect(subject).to be_local
        expect(subject).to be_local_database
      end

      it "should respect parameter " do
        subject.parse(%w(--hostname abc  --region 1))
        expect(subject.hostname).to eq("abc")
        expect(subject).to be_database
        expect(subject).not_to be_local
        expect(subject).not_to be_local_database
      end
    end

    context "#local?" do
      ["localhost", "127.0.0.1", "", nil].each do |host|
        it "should know #{host} is local" do
          expect(subject).to be_local(host)
        end
      end

      it "should know otherhost is not local" do
        expect(subject).not_to be_local("otherhost")
      end
    end

    context "#key" do
      # do not access key_configuration variable until after parsing command line
      let(:key_configuration) { subject.key_configuration }
      context "no key" do
        context "local database" do
          context "remote host specified" do
            it "fetches a key" do
              subject.parse(%w(--internal --region 1 --fetch-key remotesystem.com  --sshpassword pass))
              expect_v2_key(false)
              expect(subject).to receive(:say).with(/fetch/)
              expect(key_configuration.action).to eq(:fetch)
              expect(key_configuration.force).to eq(true)
              expect(key_configuration.host).to eq("remotesystem.com")
              expect(key_configuration.login).to eq("root")
              expect(key_configuration.password).to eq("pass")
              expect(subject).to be_key
              # only need to test get_key this once
              expect(key_configuration).to receive(:activate).and_return(true)
              subject.create_key
            end
          end

          context "no remote specified" do
            it "generates key locally" do
              subject.parse(%w(--internal --region 1))
              expect_v2_key(false)
              expect(subject).to be_key
              expect(key_configuration.action).to eq(:create)
            end
          end
        end

        context "remote database" do
          it "does not generate an encryption key" do
            subject.parse(%w(--hostname xyc.com))
            expect_v2_key(false)
            expect(subject).not_to be_key
          end
        end
      end
      context "key exists" do
        context "local database" do
          it "does not generate an encryption key" do
            subject.parse(%w(--internal --region 1))
            expect_v2_key(true)
            expect(subject).not_to be_key
            expect(key_configuration.force).to eq(false)
          end
        end

        it "fails to generate an encryption key" do
          expect($stderr).to receive(:puts).at_least(2).times
          subject.parse(%w(--internal --region 1 --key))
          expect_v2_key(true)
          expect(subject).to be_key
          expect(key_configuration.force).to eq(false)
          expect(key_configuration.activate).to eq(false)
        end

        it "forecefully removes existing encryption keys" do
          subject.parse(%w(--internal --region 1 --key --force-key))
          expect_v2_key(true)
          expect(subject).to be_key
          expect(key_configuration.force).to eq(true)
        end
      end
    end

    context "#ca" do
      it "should default to ipa" do
        expect(subject.parse(%w()).options[:ca]).to eq("ipa")
      end

      it "should support sneakernet" do
        expect(subject.parse(%w(--ca sneakernet)).options[:ca]).to eq("sneakernet")
      end
    end

    context "#certs?" do
      it "should install certs if postgres client is specified" do
        expect(subject.parse(%w(--postgres-client-cert))).to be_certs
      end

      it "should install certs if postgres server is specified" do
        expect(subject.parse(%w(--postgres-server-cert))).to be_certs
      end

      it "should install certs if a http is specified" do
        expect(subject.parse(%w(--http-cert))).to be_certs
      end

      it "should install certs if all params are specified" do
        expect(subject.parse(%w(--postgres-client-cert --postgres-server-cert --http-cert))).to be_certs
      end
    end
  end

  context "#disk_from_string" do
    before do
      allow(LinuxAdmin::Disk).to receive_messages(:local => [
        double(:path => "/dev/a", :partitions => %w(currently used)),
        double(:path => "/dev/b", :partitions => %w())
      ])
    end
    it "should return none if no path provided" do
      expect(subject.disk_from_string("")).to be_nil
      expect(subject.disk_from_string(nil)).to be_nil
    end

    it "should use first partition for dbdisk auto" do
      expect(subject.disk_from_string("auto").path).to eq("/dev/b")
    end

    it "should search by name" do
      expect(subject.disk_from_string("/dev/a").path).to eq("/dev/a")
      expect(subject.disk_from_string("/dev/b").path).to eq("/dev/b")
    end
  end

  context "#extauth_opts" do
    it "should handle setting external auth options with partial key" do
      extauth_opts = double
      expect(ApplianceConsole::ExternalAuthOptions).to receive(:new).and_return(extauth_opts)
      expect(extauth_opts).to receive(:parse)
        .with("sso_enabled=true")
        .and_return("/authentication/sso_enabled" => true)
      expect(extauth_opts).to receive(:update_configuration).with("/authentication/sso_enabled" => true)
      subject.parse(%w(--extauth-opts sso_enabled=true)).run
    end

    it "should handle setting external auth options with fully qualified key" do
      extauth_opts = double
      expect(ApplianceConsole::ExternalAuthOptions).to receive(:new).and_return(extauth_opts)
      expect(extauth_opts).to receive(:parse)
        .with("/authentication/local_login_disabled=false")
        .and_return("/authentication/local_login_disabled" => false)
      expect(extauth_opts).to receive(:update_configuration).with("/authentication/local_login_disabled" => false)
      subject.parse(%w(--extauth-opts /authentication/local_login_disabled=false)).run
    end

    it "should fail with invalid external auth options" do
      extauth_opts = double
      expect(ApplianceConsole::ExternalAuthOptions).to receive(:new).and_return(extauth_opts)
      expect(extauth_opts).to receive(:parse).with("invalid_auth_option=true").and_return({})
      expect do
        subject.parse(%w(--extauth-opts invalid_auth_option=true)).run
      end.to raise_error(/Must specify at least one/)
    end
  end

  private

  def expect_v2_key(exists = true)
    allow(subject.key_configuration).to receive(:key_exist?).and_return(exists)
  end
end
