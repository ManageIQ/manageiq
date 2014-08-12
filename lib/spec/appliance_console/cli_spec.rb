require "spec_helper"
require 'appliance_console/env'
require "appliance_console/cli"

RAILS_ROOT ||= File.expand_path("../../../vmdb", Pathname.new(__FILE__).realpath)

describe ApplianceConsole::Cli do
  subject { described_class.new }

  it "should set hostname if defined" do
    ApplianceConsole::Env.should_receive(:[]=).with(:host, 'host1')

    subject.parse(%w{--host host1}).run
  end

  it "should not set hostname if none specified" do
    ApplianceConsole::Env.should_not_receive(:[]=).with(:host, anything)

    subject.parse(%w{}).run
  end

  it "should set database host to localhost if running locally" do
    subject.should_receive(:disk_from_string).and_return('x')
    ApplianceConsole::InternalDatabaseConfiguration.should_receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'root',
            :interactive => false,
            :disk        => 'x')
      .and_return(stub(:activate => true, :post_activation => true))

    subject.parse(%w{--internal -r 1 --dbdisk x}).run
  end

  it "should pass username and password when configuring database locally" do
    subject.should_receive(:disk_from_string).and_return('x')
    ApplianceConsole::InternalDatabaseConfiguration.should_receive(:new)
      .with(:region      => 1,
            :database    => 'vmdb_production',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false,
            :disk        => 'x')
      .and_return(stub(:activate => true, :post_activation => true))

    subject.parse(%w(--internal --username user --password pass -r 1 --dbdisk x)).run
  end

  it "should handle remote databases (and setup region)" do
    ApplianceConsole::ExternalDatabaseConfiguration.should_receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :region      => 1,
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(stub(:activate => true, :post_activation => true))

    subject.parse(%w{--hostname host --dbname db --username user --password pass -r 1}).run
  end

  it "should handle remote databases (not setting up region)" do
    ApplianceConsole::ExternalDatabaseConfiguration.should_receive(:new)
      .with(:host        => 'host',
            :database    => 'db',
            :username    => 'user',
            :password    => 'pass',
            :interactive => false)
      .and_return(stub(:activate => true, :post_activation => true))

    subject.parse(%w{--hostname host --dbname db --username user --password pass}).run
  end

  context "parse" do
    context "#hostname and local?" do
      it "should not default" do
        expect(subject.hostname).to be_nil
      end

      it "should have 'localhost' for internal databases" do
        subject.parse(%w{--internal --region 1})
        expect(subject.hostname).to eq("localhost")
        expect(subject).to be_local
      end

      it "should be local (even if explicitly setting hostname" do
        subject.parse(%w{--hostname localhost --region 1})
        expect(subject).to be_local
      end

      it "should respect parameter " do
        subject.parse(%w{--hostname abc  --region 1})
        expect(subject.hostname).to eq("abc")
        expect(subject).not_to be_local
      end

      ["localhost", "127.0.0.1", "", nil].each do |host|
        it "should know #{host} is local" do
          expect(subject).to be_local(host)
        end
      end

      it "should know otherhost is not local" do
        expect(subject).not_to be_local("otherhost")
      end
    end

    context "#cahost" do
      it "should ignore cahost if not setting up a ca" do
        subject.parse(%w{--cahost x})
        expect(subject.cahost).to be_blank
      end

      it "should default to localhost when setting up a ca" do
        subject.parse(%w{--ca})
        expect(subject.cahost).to eq("localhost")
      end

      it "should ignore cahost if not setting up a ca" do
        subject.parse(%w{--ca --cahost x})
        expect(subject.cahost).to eq("x")
      end
    end

    context "#key" do
      it "should setup a key if passing --key" do
        subject.parse(%w(--key))
        expect(subject).to be_key
      end

      it "should setup key for localhost" do
        subject.parse(%w(--ca))
        expect(subject).to be_key
      end

      it "should setup key for localhost" do
        subject.parse(%w(--ca --cahost localhost))
        expect(subject).to be_key
      end

      it "should not setup key for remote host" do
        subject.parse(%w(--ca --cahost x))
        expect(subject).not_to be_key
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

end
