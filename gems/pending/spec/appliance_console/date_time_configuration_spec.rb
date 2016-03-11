require "appliance_console/date_time_configuration"

describe ApplianceConsole::DateTimeConfiguration do
  subject { described_class.new }

  before do
    allow(subject).to receive(:say)
    allow(subject).to receive(:clear_screen)
    allow(subject).to receive(:agree)
  end

  context "#ask_questions" do
    it "returns true when all user input is provided" do
      expect(subject).to receive(:ask_establish_auto_sync).and_return(true)
      expect(subject).to receive(:ask_for_date).and_return(true)
      expect(subject).to receive(:ask_for_time).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns false when apply date time is canceled" do
      expect(subject).to receive(:ask_establish_auto_sync).and_return(true)
      expect(subject).to receive(:ask_for_date).and_return(true)
      expect(subject).to receive(:ask_for_time).and_return(true)
      expect(subject).to receive(:confirm).and_return(false)
      expect(subject.ask_questions).to be false
    end

    it "returns false when new time is canceled" do
      expect(subject).to receive(:ask_establish_auto_sync).and_return(true)
      expect(subject).to receive(:ask_for_date).and_return(true)
      expect(subject).to receive(:ask_for_time).and_return(false)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "returns false when new date is canceled" do
      expect(subject).to receive(:ask_establish_auto_sync).and_return(true)
      expect(subject).to receive(:ask_for_date).and_return(false)
      expect(subject).to_not receive(:ask_for_time)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "Continues asking when disable auto sync returns false" do
      expect(subject).to receive(:ask_establish_auto_sync).and_return(false)
      expect(subject).to receive(:ask_for_date).and_return(true)
      expect(subject).to receive(:ask_for_time).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end
  end

  context "#ask_establish_auto_sync" do
    it "asks confirmation to disable auto sync" do
      expect(subject).to receive(:agree).and_return(true)
      expect(subject.ask_establish_auto_sync).to be true
      expect(subject.manual_time_sync).to be true
    end

    it "returns false when automatic time sycn is requested" do
      allow(subject).to receive(:agree).and_return(false)
      expect(subject.ask_establish_auto_sync).to be false
      expect(subject.manual_time_sync).to be false
    end
  end

  context "#ask_for_date" do
    it "asks for a new date" do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect(subject).to receive(:just_ask).and_return('2000-01-01')
      expect(subject.ask_for_date).to be true
      expect(subject.new_date).to eq('2000-01-01')
    end

    it "Does not asks for a new date when auto time sync" do
      subject.instance_variable_set(:@manual_time_sync, false)
      expect(subject).to_not receive(:just_ask)
      expect(subject.ask_for_date).to be true
    end

    it "returns false when cancel is requested" do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect { subject.just_ask }.to raise_error(StandardError)
      expect(subject.ask_for_date).to be false
    end
  end

  context "#ask_for_time" do
    it "asks for a new time " do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect(subject).to receive(:just_ask).and_return('01:23:45')
      expect(subject.ask_for_time).to be true
      expect(subject.new_time).to eq('01:23:45')
    end

    it "Does not asks for a new time when auto time sync" do
      subject.instance_variable_set(:@manual_time_sync, false)
      expect(subject).to_not receive(:just_ask)
      expect(subject.ask_for_time).to be true
    end

    it "returns false when cancel is requested" do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect { subject.just_ask }.to raise_error(StandardError)
      expect(subject.ask_for_time).to be false
    end
  end

  context "#confirm_manual" do
    before do
      subject.instance_variable_set(:@new_date, '2000-01-01')
      subject.instance_variable_set(:@new_time, '01:23:45')
      subject.instance_variable_set(:@manual_time_sync, false)
    end

    it "asks to apply manual date / time" do
      expect(subject).to receive(:agree).and_return(true)
      expect(subject.confirm).to be true
    end

    it "returns false when cancel is requested" do
      expect(subject).to receive(:agree).and_return(false)
      expect(subject.confirm).to be false
    end
  end

  context "#confirm_auto" do
    before do
      subject.instance_variable_set(:@manual_time_sync, true)
    end

    it "asks to apply automatic date / time" do
      expect(subject).to receive(:agree).and_return(true)
      expect(subject.confirm).to be true
    end

    it "returns false when cancel is requested" do
      expect(subject).to receive(:agree).and_return(false)
      expect(subject.confirm).to be false
    end
  end

  context "#disable_auto_sync" do
    before do
      subject.instance_variable_set(:@manual_time_sync, true)
    end

    it "Disables auto time and date synchronization" do
      expect(LinuxAdmin::Service).to receive(:new).and_return(double(:stop => double(:disable => nil)))
      expect(LinuxAdmin::Service).to receive(:new).and_return(double(:restart => nil))
      expect(subject.establish_auto_sync).to be true
    end

    it "returns false when a failure is detected" do
      expect(LinuxAdmin::Service).to receive(:new).and_raise("Error")
      expect(subject.establish_auto_sync).to be false
    end
  end

  context "#enable_auto_sync" do
    before do
      subject.instance_variable_set(:@manual_time_sync, false)
    end

    it "enables auto time and date synchronization" do
      expect(LinuxAdmin::Service).to receive(:new).and_return(double(:enable => double(:start => nil)))
      expect(LinuxAdmin::Service).to receive(:new).and_return(double(:restart => nil))
      expect(subject.establish_auto_sync).to be true
    end

    it "returns false when a failure is detected" do
      expect(LinuxAdmin::Service).to receive(:new).and_raise("Error")
      expect(subject.establish_auto_sync).to be false
    end
  end

  context "#configure_date_time" do
    it "cofigures the system date and time" do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect(Time).to receive(:parse).and_return(double(:getlocal => nil))
      expect(LinuxAdmin::TimeDate).to receive(:system_time=).and_return(nil)
      expect(subject.configure_date_time).to be true
    end

    it "does not cofigures the system date and time when auto sync" do
      subject.instance_variable_set(:@manual_time_sync, false)
      expect(Time).to_not receive(:parse)
      expect(LinuxAdmin::TimeDate).to_not receive(:system_time=)
      expect(subject.configure_date_time).to be true
    end

    it "returns false when a failure is detected" do
      subject.instance_variable_set(:@manual_time_sync, true)
      expect(Time).to receive(:parse).and_return(double(:getlocal => nil))
      expect(LinuxAdmin::TimeDate).to receive(:system_time=).and_raise("Error")
      expect(subject.configure_date_time).to be false
    end
  end

  context "#activate" do
    before do
      allow(subject).to receive(:say)
    end

    it "returns true when auto sync and configure succeed" do
      expect(subject).to receive(:establish_auto_sync).and_return(true)
      expect(subject).to receive(:configure_date_time).and_return(true)
      expect(subject.activate).to be true
    end

    it "returns false when configure is canceled" do
      expect(subject).to receive(:establish_auto_sync).and_return(true)
      expect(subject).to receive(:configure_date_time).and_return(false)
      expect(subject.activate).to be false
    end

    it "returns false when establish auto sync fails" do
      expect(subject).to receive(:establish_auto_sync).and_return(false)
      expect(subject).to_not receive(:configure_date_time)
      expect(subject.activate).to be false
    end

    it "returns false when configure date time fails" do
      expect(subject).to receive(:establish_auto_sync).and_return(true)
      expect(subject).to receive(:configure_date_time).and_return(false)
      expect(subject.activate).to be false
    end
  end
end
