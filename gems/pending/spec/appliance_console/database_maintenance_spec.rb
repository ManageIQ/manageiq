require "appliance_console/database_maintenance"

describe ApplianceConsole::DatabaseMaintenance do
  SPEC_NAME = File.basename(__FILE__).split(".rb").first.freeze

  describe "#ask_questions" do
    before do
      @confirmed = double(SPEC_NAME, :confirm => true)
      @not_confirmed = double(SPEC_NAME, :confirm => false)
    end

    context "when hourly is confirmed and periodic is not confirmed" do
      before do
        expect(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@confirmed)
        expect(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@not_confirmed)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.ask_questions).to eq(true)
      end
    end

    context "when hourly is not confirmed and periodic is confirmed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@not_confirmed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@confirmed)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.ask_questions).to eq(true)
      end
    end

    context "when both hourly and periodic are confirmed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@confirmed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@confirmed)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.ask_questions).to eq(true)
      end
    end

    context "when both hourly and periodic are not confirmed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@not_confirmed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@not_confirmed)
        allow(subject).to receive(:clear_screen)
      end

      it "returns false" do
        expect(subject.ask_questions).to eq(false)
      end
    end
  end

  describe "#activate" do
    before do
      @executed = double(SPEC_NAME, :activate => true)
      @not_executed = double(SPEC_NAME, :activate => false)
    end

    context "when hourly is executed and periodic is not executed" do
      before do
        expect(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@executed)
        expect(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@not_executed)
        allow(subject).to receive(:say)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.activate).to eq(true)
      end
    end

    context "when hourly is not executed and periodic is executed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@not_executed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@executed)
        allow(subject).to receive(:say)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.activate).to eq(true)
      end
    end

    context "when both hourly and periodic are executed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@executed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@executed)
        allow(subject).to receive(:say)
        allow(subject).to receive(:clear_screen)
      end

      it "returns true" do
        expect(subject.activate).to eq(true)
      end
    end

    context "when neither hourly or periodic are executed" do
      before do
        allow(ApplianceConsole::DatabaseMaintenanceHourly).to receive(:new).and_return(@not_executed)
        allow(ApplianceConsole::DatabaseMaintenancePeriodic).to receive(:new).and_return(@not_executed)
        allow(subject).to receive(:say)
        allow(subject).to receive(:clear_screen)
      end

      it "returns false" do
        expect(subject.activate).to eq(false)
      end
    end
  end
end
