require "appliance_console/timezone_configuration"

describe ApplianceConsole::TimezoneConfiguration do
  subject { described_class.new('US/Eastern') }

  context "#ask_questions" do
    it "returns true when all user input is provided" do
      expect(subject).to receive(:ask_timezone_area).and_return(true)
      expect(subject).to receive(:ask_timezone_city).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to_not be false
    end

    it "returns false when apply timezone is canceled" do
      expect(subject).to receive(:ask_timezone_area).and_return(true)
      expect(subject).to receive(:ask_timezone_city).and_return(true)
      expect(subject).to receive(:confirm).and_return(false)
      expect(subject.ask_questions).to be false
    end

    it "returns false when new city is canceled" do
      expect(subject).to receive(:ask_timezone_area).and_return(true)
      expect(subject).to receive(:ask_timezone_city).and_return(false)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "returns false when new area is canceled" do
      expect(subject).to receive(:ask_timezone_area).and_return(false)
      expect(subject).to_not receive(:ask_timezone_city)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end
  end

  context "#ask_timezone_area" do
    it "asks for a new timezone area" do
      expect(subject).to receive(:ask_with_menu).and_return('United States')
      expect(subject.ask_timezone_area).to be true
      expect(subject.new_loc).to eq('US')
    end

    it "returns false when cancel is requested" do
      expect(subject).to receive(:ask_with_menu).and_return(ApplianceConsole::CANCEL)
      expect(subject.ask_timezone_area).to be false
    end
  end

  context "#ask_timezone_city" do
    before { subject.instance_variable_set(:@new_loc, 'US') }

    it "asks for a new timezone city" do
      expect(subject).to receive(:ask_with_menu).and_return('Alaska')
      expect(subject.ask_timezone_city).to be true
      expect(subject.new_city).to eq('Alaska')
    end

    it "returns false when cancel is requested" do
      expect(subject).to receive(:ask_with_menu).and_return(ApplianceConsole::CANCEL)
      expect(subject.ask_timezone_city).to be false
    end
  end

  context "#confirm" do
    before do
      subject.instance_variable_set(:@tz_area, 'US')
      subject.instance_variable_set(:@new_city, 'Alaska')
      allow(subject).to receive(:clear_screen)
      allow(subject).to receive(:say)
    end

    it "asks to apply timezone" do
      expect(subject).to receive(:agree).and_return(true)
      expect(subject.confirm).to be true
    end

    it "returns false when cancel is requested" do
      expect(subject).to receive(:agree).and_return(false)
      expect(subject.confirm).to be false
    end
  end

  context "#activate" do
    before do
      expect(subject).to receive(:log_and_feedback).and_yield
      allow(subject).to receive(:say)
    end

    it "Applies the requested timezone" do
      expect(LinuxAdmin::TimeDate).to receive(:system_timezone=)
      expect(subject.activate).to be_truthy
    end

    it "returns false on failure" do
      expect(LinuxAdmin::TimeDate).to receive(:system_timezone=).and_raise(LinuxAdmin::TimeDate::TimeCommandError)
      expect(subject.activate).to be_falsy
    end
  end
end
