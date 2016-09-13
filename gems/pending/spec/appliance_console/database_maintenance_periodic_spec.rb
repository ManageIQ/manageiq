require "appliance_console/database_maintenance_periodic"

describe ApplianceConsole::DatabaseMaintenancePeriodic do
  before do
    @test_crontab_1 = Tempfile.new
    stub_const("ApplianceConsole::DatabaseMaintenancePeriodic::CRONTAB_FILE", @test_crontab_1.path)
    allow(subject).to receive(:say)
    allow(subject).to receive(:clear_screen)
    allow(subject).to receive(:agree)
  end

  after do
    FileUtils.rm_f(@test_crontab_1.path)
  end

  describe "#confirm" do
    context "when not configured" do
      before do
        subject.already_configured = false
        expect(subject).to receive(:agree).with(/configure periodic database maintenance/i).and_return(true)
      end

      it "creates a new hourly crontab entry" do
        expect(subject).to receive(:ask_for_schedule_frequency).and_return("hourly")
        expect(subject.confirm).to eq("0 * * * *")
      end

      it "creates a daily crontab entry with user supplied hour" do
        expect(subject).to receive(:ask_for_schedule_frequency).and_return("daily")
        expect(subject).to receive(:ask_for_hour_number).and_return(23)
        expect(subject.confirm).to eq("0 23 * * *")
      end

      it "creates a weekly crontab entry with user supplied hour and weekday" do
        expect(subject).to receive(:ask_for_schedule_frequency).and_return("weekly")
        expect(subject).to receive(:ask_for_hour_number).and_return(23)
        expect(subject).to receive(:ask_for_week_day_number).and_return(2)
        expect(subject.confirm).to eq("0 23 * * 2")
      end

      it "creates a monthly crontab entry with user supplied hour and day of month" do
        expect(subject).to receive(:ask_for_schedule_frequency).and_return("monthly")
        expect(subject).to receive(:ask_for_hour_number).and_return(23)
        expect(subject).to receive(:ask_for_month_day_number).and_return(26)
        expect(subject.confirm).to eq("0 23 26 * *")
      end
    end

    context "when already configured" do
      before do
        subject.already_configured = true
        expect(subject).to receive(:agree).with(/periodic database maintenance is already configured/i).and_return(true)
      end

      it "confirms un-configure" do
        expect(subject.confirm).to eq(true)
      end
    end
  end

  describe "#activate" do
    context "when activation requested" do
      before do
        subject.requested_activate = true

        subject.crontab_schedule_expression = "0 23 26 * *"
        @test_crontab = Tempfile.new(subject.class.name.split("::").last.downcase)
        stub_const("ApplianceConsole::DatabaseMaintenancePeriodic::CRONTAB_FILE", @test_crontab.path)
      end

      after do
        FileUtils.rm_f(@test_crontab.path)
      end

      let(:expected_crontab_file) do
        <<-EOT.strip_heredoc
          0 23 26 * * root /usr/bin/periodic_vacuum_full_tables
        EOT
      end

      it "appends the periodic database maintenance entry to the crontab" do
        subject.activate
        expect(File.read(@test_crontab)).to eq(expected_crontab_file)
      end
    end

    context "when deactivation requested" do
      let(:seeded_crontab_file) do
        <<-EOT.strip_heredoc
          SHELL=/bin/bash
          PATH=/sbin:/bin:/usr/sbin:/usr/bin
          MAILTO=root
          * * * * * user program_path_to_run_every_minute
          0 3 6 * * root /usr/bin/periodic_vacuum_full_tables
        EOT
      end

      let(:expected_crontab_file) do
        <<-EOT.strip_heredoc
          SHELL=/bin/bash
          PATH=/sbin:/bin:/usr/sbin:/usr/bin
          MAILTO=root
          * * * * * user program_path_to_run_every_minute
        EOT
      end

      before do
        subject.requested_deactivate = true

        @test_crontab = Tempfile.new(subject.class.name.split("::").last.downcase)
        stub_const("ApplianceConsole::DatabaseMaintenancePeriodic::CRONTAB_FILE", @test_crontab.path)
        File.open(@test_crontab, "a") do |f|
          f.write(seeded_crontab_file)
        end
      end

      after do
        FileUtils.rm_f(@test_crontab.path)
      end

      it "removes the periodic database maintenance entries from the crontab" do
        subject.activate
        expect(File.read(@test_crontab)).to eq(expected_crontab_file)
      end
    end
  end
end
