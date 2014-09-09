require "spec_helper"
require 'appliance_console/env'
require "appliance_console/cli"

RAILS_ROOT ||= File.expand_path("../../../vmdb", Pathname.new(__FILE__).realpath)

describe ApplianceConsole::Cli do
  subject { described_class.new }

  it "should set hostname if defined" do
    ApplianceConsole::Env.should_receive(:[]=).with(:host, 'host1')

    subject.parse(%w(--host host1)).run
  end

  it "should not set hostname if none specified" do
    ApplianceConsole::Env.should_not_receive(:[]=).with(:host, anything)

    subject.parse([]).run
  end

  context "#database" do
    it "requires v2_key" do
      expect_any_instance_of(ApplianceConsole::KeyConfiguration).to receive(:key_exist?).and_return(false)
      expect { subject.parse(%w(--internal -r 1 --dbdisk x)).run }.to raise_error("No v2_key present")
    end
  end

  it "should set database host to localhost if running locally" do
    expect_v2_key
    subject.should_receive(:disk_from_string).with('x').and_return('/dev/x')
    subject.should_receive(:say)
    ApplianceConsole::InternalDatabaseConfiguration.should_receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'root',
            :interactive => false,
            :disk        => '/dev/x')
      .and_return(double(:activate => true, :post_activation => true))

    subject.parse(%w(--internal -r 1 --dbdisk x)).run
  end

  it "should pass username and password when configuring database locally" do
    expect_v2_key
    subject.should_receive(:disk_from_string).and_return('x')
    subject.should_receive(:say)
    ApplianceConsole::InternalDatabaseConfiguration.should_receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false,
            :disk        => 'x')
      .and_return(double(:activate => true, :post_activation => true))

    subject.parse(%w(--internal --username user --password pass -r 1 --dbdisk x)).run
  end

  it "should handle remote databases (and setup region)" do
    expect_v2_key
    subject.should_receive(:say)
    ApplianceConsole::ExternalDatabaseConfiguration.should_receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :region      => 1,
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(double(:activate => true, :post_activation => true))

    subject.parse(%w(--hostname host --dbname db --username user --password pass -r 1)).run
  end

  it "should handle remote databases (not setting up region)" do
    expect_v2_key
    subject.should_receive(:say)
    ApplianceConsole::ExternalDatabaseConfiguration.should_receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(double(:activate => true, :post_activation => true))

    subject.parse(%w(--hostname host --dbname db --username user --password pass)).run
  end

  context "#ipa" do
    it "should handle uninstalling ipa" do
      subject.should_receive(:say)
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:new)
        .and_return(double(:ipa_client_configured? => true, :ipa_client_unconfigure => nil))
      subject.parse(%w(--uninstall-ipa)).run
    end

    it "should skip uninstalling ipa if not installed" do
      subject.should_receive(:say)
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:new)
        .and_return(double(:ipa_client_configured? => false))
      subject.parse(%w(--uninstall-ipa)).run
    end

    it "should install ipa" do
      ApplianceConsole::Env.should_receive(:[]).with("host").and_return('client.domain.com')
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:ipa_client_configured?).and_return(false)
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:new)
          .with('client.domain.com',
                :ipaserver => 'ipa.domain.com',
                :principal => 'admin',
                :realm     => 'domain.com',
                :password  => 'pass').and_return(double(:activate => true, :post_activation => nil))
      subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass --iparealm domain.com)).run
    end

    it "should not post_activate install ipa (aside: testing passing in host" do
      ApplianceConsole::Env.should_receive(:[]=).with(:host, "client.domain.com")
      ApplianceConsole::Env.should_not_receive(:[]).with(:host)
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:ipa_client_configured?).and_return(false)
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:new)
          .with('client.domain.com',
                :ipaserver => 'ipa.domain.com',
                :principal => 'admin',
                :realm     => nil,
                :password  => 'pass').and_return(double(:activate => false))
      subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass --host client.domain.com)).run
    end

    it "should complain if installing ipa-client when ipa is already installed" do
      ApplianceConsole::ExternalHttpdAuthentication.should_receive(:ipa_client_configured?).and_return(true)
      expect do
        subject.parse(%w(--ipaserver ipa.domain.com --ipaprincipal admin --ipapassword pass)).run
      end.to raise_error(/uninstall/)
    end
  end

  context "#install_certs" do
    it "should basic install completed (default ca_name, non verbose)" do
      subject.should_receive(:say).with(/creating/)
      ApplianceConsole::Env.should_receive(:[]).with("host").and_return('client.domain.com')
      subject.should_receive(:say).with(/certificate result/)
      subject.should_not_receive(:say).with(/rerun/)
      ApplianceConsole::CertificateAuthority.should_receive(:new)
        .with(
          :hostname => "client.domain.com",
          :realm    => nil,
          :ca_name  => "ipa",
          :pgclient => true,
          :pgserver => false,
          :api      => true,
          :verbose  => false,
        ).and_return(double(:activate => true, :status_string => "good", :complete? => true))

      subject.parse(%w(--postgres-client-cert --api-cert)).run
    end

    it "should basic install waiting (manual ca_name, verbose)" do
      subject.should_receive(:say).with(/creating/)
      ApplianceConsole::Env.should_receive(:[]).with("host").and_return('client.domain.com')
      subject.should_receive(:say).with(/certificate result/)
      subject.should_receive(:say).with(/rerun/)
      ApplianceConsole::CertificateAuthority.should_receive(:new)
        .with(
          :hostname => "client.domain.com",
          :realm    => "realm.domain.com",
          :ca_name  => "super",
          :pgclient => false,
          :pgserver => true,
          :api      => false,
          :verbose  => true,
        ).and_return(double(:activate => true, :status_string => "good", :complete? => false))

      subject.parse(%w(--postgres-server-cert --verbose --ca super --iparealm realm.domain.com)).run
    end
  end

  context "#config_tmp_disk" do
    it "configures disk" do
      subject.should_receive(:disk_from_string).with('x').and_return('/dev/x')
      subject.should_receive(:say)
      ApplianceConsole::TempStorageConfiguration.should_receive(:new)
        .with(:disk      => '/dev/x')
      .and_return(double(:activate => true))

      subject.parse(%w(--tmpdisk x)).run
    end
  end

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
      it "should setup a key if passing --key" do
        subject.parse(%w(--key))
        expect(subject).to be_key
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

      it "should install certs if a api is specified" do
        expect(subject.parse(%w(--api-cert))).to be_certs
      end

      it "should install certs if all params are specified" do
        expect(subject.parse(%w(--postgres-client-cert --postgres-server-cert --api-cert))).to be_certs
      end
    end
  end

  context "#disk_from_string" do
    before do
      LinuxAdmin::Disk.stub(:local => [
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

  private

  def expect_v2_key
    expect_any_instance_of(ApplianceConsole::KeyConfiguration).to receive(:key_exist?).and_return(true)
  end
end
