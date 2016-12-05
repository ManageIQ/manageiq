require "appliance_console/timezone_configuration"

describe ApplianceConsole::TimezoneConfiguration do
  subject { described_class.new('US/Eastern') }

  let(:timezone_hash) do
    {
      "Africa"  => {
        "Abidijan" => "Africa/Abidijan"
      },
      "America" => {
        "Argentina" => {
          "Buenos_Aires" => "America/Argentina/Buenos_Aires"
        }
      },
      "UTC"     => "UTC"
    }
  end

  describe "#ask_questions" do
    it "returns true when all user input is provided" do
      expect(subject).to receive(:ask_for_timezone).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end
  end

  describe "#ask_for_timezone" do
    before do
      expect(subject).to receive(:timezone_hash).and_return(timezone_hash)
    end

    it "prompts once for non-nested timezones" do
      expect(subject).to receive(:ask_with_menu).once
        .with("Geographic Location", %w(Africa America UTC), nil, false)
        .and_return("UTC")

      expect(subject.ask_for_timezone).to be true

      expect(subject.new_timezone).to eq("UTC")
    end

    it "prompts multiple times for nested timezones" do
      expect(subject).to receive(:ask_with_menu)
        .with("Geographic Location", %w(Africa America UTC), nil, false)
        .and_return("America").ordered
      expect(subject).to receive(:ask_with_menu)
        .with("Geographic Location", ["Argentina"], nil, false)
        .and_return("Argentina").ordered
      expect(subject).to receive(:ask_with_menu)
        .with("Geographic Location", ["Buenos_Aires"], nil, false)
        .and_return("Buenos_Aires").ordered

      expect(subject.ask_for_timezone).to be true

      expect(subject.new_timezone).to eq("America/Argentina/Buenos_Aires")
    end
  end

  describe "#confirm" do
    before do
      allow(subject).to receive(:clear_screen)
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

  describe "#activate" do
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

  describe "#timezone_hash" do
    it "returns the correct hash" do
      expect(LinuxAdmin::TimeDate).to receive(:timezones).and_return(%w(Africa/Abidijan UTC America/Argentina/Buenos_Aires))
      expect(subject.timezone_hash).to eq(timezone_hash)
    end
  end
end
