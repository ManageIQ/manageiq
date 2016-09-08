require "appliance_console/database_maintenance_hourly"

describe ApplianceConsole::DatabaseMaintenanceHourly do
  DIRNAME = File.dirname(__FILE__).freeze

  before do
    allow(subject).to receive(:say)
  end

  describe "#confirm" do
    before do
      allow(subject).to receive(:say)
      allow(subject).to receive(:clear_screen)
      allow(subject).to receive(:agree)
    end

    context "when not configured" do
      before do
        subject.already_configured = false
        test_hourly_cron = "#{Dir.tmpdir}/miq-pg-maintenance-hourly.cron"
        stub_const("ApplianceConsole::DatabaseMaintenanceHourly::HOURLY_CRON", test_hourly_cron)
      end

      it "returns true when configure is confirmed" do
        expect(subject).to receive(:agree).with(/configure hourly database maintenance/i).and_return(true)
        expect(subject.confirm).to be true
      end

      it "returns false when configure is not confirmed" do
        expect(subject).to receive(:agree).with(/configure hourly database maintenance/i).and_return(false)
        expect(subject.confirm).to be false
      end
    end

    context "when already configured" do
      before do
        subject.already_configured = true
        @test_hourly_cron = Tempfile.new(subject.class.name.split("::").last.downcase)
        stub_const("ApplianceConsole::DatabaseMaintenanceHourly::HOURLY_CRON", @test_hourly_cron.path)
      end

      after do
        FileUtils.rm_f(@test_hourly_cron.path)
      end

      it "returns true when un-configure is confirmed" do
        expect(subject).to receive(:agree).with(/un-configure/i).and_return(true)
        expect(subject.confirm).to be true
      end

      it "returns false when un-configure is not confirmed" do
        expect(subject).to receive(:agree).with(/un-configure/i).and_return(false)
        expect(subject.confirm).to be false
      end
    end
  end

  describe "#activate" do
    context "when activation requsted" do
      before do
        @test_hourly_cron = "#{Dir.tmpdir}/miq-pg-maintenance-hourly.cron"
        stub_const("ApplianceConsole::DatabaseMaintenanceHourly::HOURLY_CRON", @test_hourly_cron)
        subject.requested_activate = true
      end

      after do
        FileUtils.rm_f(@test_hourly_cron)
      end

      let(:expected_cron_file) do
        <<-EOT.strip_heredoc
          #!/bin/sh
          /usr/bin/hourly_reindex_metrics_tables
          /usr/bin/hourly_reindex_miq_queue_table
          /usr/bin/hourly_reindex_miq_workers_table
          exit 0
        EOT
      end

      it "creates a new hourly cron job" do
        expect(FileUtils).to receive(:chmod).with(0755, @test_hourly_cron)
        subject.activate
        expect(File.read(@test_hourly_cron)).to eq(expected_cron_file)
      end
    end

    context "when deactivation requsted" do
      before do
        @test_hourly_cron = Tempfile.new(subject.class.name.split("::").last.downcase)
        stub_const("ApplianceConsole::DatabaseMaintenanceHourly::HOURLY_CRON", @test_hourly_cron.path)
        subject.requested_deactivate = true
      end

      after do
        FileUtils.rm_f(@test_hourly_cron.path)
      end

      it "removes the existing hourly cron job" do
        subject.activate
        expect(File.exist?(@test_hourly_cron.path)).to eq(false)
      end
    end
  end
end
