require "appliance_console/logfile_configuration"

describe ApplianceConsole::LogfileConfiguration do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first.freeze
    allow(LinuxAdmin::Service).to receive(:new).and_return(double(@spec_name, :running? => false))
    allow(subject).to receive(:clear_screen)
    allow(subject).to receive(:say)
  end

  describe "#ask_questions" do
    it "returns true when user confirms a new disk" do
      expect(subject).to receive(:agree).and_return(true).twice
      expect(subject).to receive(:ask_for_disk).and_return(double(:@spec_name, :size => "22", :path => "fake disk"))
      expect(subject.ask_questions).to be true
    end

    it "returns false when user does not confirm a new disk" do
      expect(subject).to receive(:agree).and_return(false)
      expect(subject).to_not receive(:ask_for_disk)
      expect(subject.ask_questions).to be false
    end

    it "returns false when user does not confirm the selection" do
      expect(subject).to receive(:agree).with("Configure a new logfile disk volume? (Y/N):").and_return(true)
      expect(subject).to receive(:agree).with(/Continue with disk:/).and_return(false)
      expect(subject).to receive(:ask_for_disk).and_return(double(:@spec_name, :size => "22", :path => "fake disk"))

      expect(subject.ask_questions).to be false
    end
  end

  describe "#activate" do
    it "stops and starts evm and configures the logfile disk" do
      expect(ApplianceConsole::LogicalVolumeManagement).to receive(:new).and_return(double(@spec_name, :setup => true))

      expect(File).to receive(:executable?).with("/sbin/restorecon").and_return(true)
      expect(AwesomeSpawn).to receive(:run!)
        .with('/usr/sbin/semanage fcontext -a -t httpd_log_t "#{LOGFILE_DIRECTORY.to_path}(/.*)?"')
      expect(AwesomeSpawn).to receive(:run!).with('/sbin/restorecon -R -v /var/www/miq/vmdb/log')

      expect(FileUtils).to receive(:mkdir_p).with("#{ApplianceConsole::LogfileConfiguration::LOGFILE_DIRECTORY}/apache")
      expect(LinuxAdmin::Service).to receive(:new)
        .and_return(double(@spec_name, :stop => nil)).twice
      expect(LinuxAdmin::Service).to receive(:new)
        .and_return(double(@spec_name, :enable => double(@spec_name, :start => true))).twice

      expect(subject.activate).to be true
    end
  end
end
