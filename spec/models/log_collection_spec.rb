RSpec.describe "LogCollection" do
  before do
    _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  context "active log_collection" do
    before do
      @log_file = FactoryBot.create(:log_file, :state => "collecting")
      @miq_server.log_files << @log_file
      @task = FactoryBot.create(:miq_task,
                                 :miq_server_id => @miq_server.id,
                                 :name          => "Zipped log retrieval for #{@miq_server.name}"
                                )
    end

    it { expect(@miq_server).to be_log_collection_active }
    it { expect(@zone).to       be_log_collection_active }
    it { expect(@miq_server).to be_log_collection_active_recently }
    it { expect(@zone).to       be_log_collection_active_recently }

    context "21 minutes ago" do
      it { expect(@miq_server.log_collection_active_recently?(21.minutes.ago.utc)).to be_truthy }
      it { expect(@zone.log_collection_active_recently?(21.minutes.ago.utc)).to       be_truthy }
    end

    context "jumping ahead in time 20 minutes" do
      before do
        Timecop.travel 20.minutes
      end

      it { expect(@miq_server).to     be_log_collection_active }
      it { expect(@zone).to           be_log_collection_active }
      it { expect(@miq_server).to_not be_log_collection_active_recently }
      it { expect(@zone).to_not       be_log_collection_active_recently }

      after do
        Timecop.return
      end
    end
  end

  context "with a log file instance" do
    before do
      @log_file          = FactoryBot.create(:log_file, :resource => @miq_server)
      @region            = FactoryBot.create(:miq_region)
      @timestamp         = "2010"
      @fname             = "/test.zip"
      allow_any_instance_of(LogFile).to receive(:format_log_time).and_return(@timestamp)
    end

    context "with a nil region column" do
      before do
        @region.update(:region => nil)
      end

      it "using a historical log file should raise no errors with a nil region column" do
        @log_file.update(:historical => true)
        expect { @log_file.relative_path_for_upload("/test.zip") }.to_not raise_error
      end
    end

    context "with my_region nil" do
      before do
        allow(MiqRegion).to receive(:my_region).and_return(nil)
      end

      it "using a historical log file should raise no errors with a nil region association" do
        @log_file.update(:historical => true)
        expect { @log_file.relative_path_for_upload("/test.zip") }.to_not raise_error
      end
    end

    %w(models dialogs current archive).each do |log_type|
      context "using a #{log_type} log file" do
        before do
          @fname = "#{log_type}.zip"
          allow(MiqRegion).to receive(:my_region).and_return(@region)
          @log_file.update(:historical => log_type != "current")
        end

        it "should build a destination directory path based on zone and server" do
          res      = @log_file.relative_path_for_upload(@fname)
          expected = "/#{@zone.name}_#{@zone.id}/#{@miq_server.name}_#{@miq_server.id}"
          expect(File.dirname(res)).to eq(expected)
        end

        it "should build a destination filename based on archive, region, zone, server and date" do
          res      = @log_file.relative_path_for_upload(@fname)
          expected = "#{log_type.capitalize}_region_#{@region.region}_#{@zone.name}_#{@zone.id}_#{@miq_server.name}_#{@miq_server.id}_#{@timestamp}_#{@timestamp}#{File.extname(@fname)}"
          expect(File.basename(res)).to eq(expected)
        end
      end
    end
  end

  context "queue item and task item creation are atomic" do
    context "with error creating task" do
      before do
        allow(MiqTask).to receive(:new).and_raise("some error message")
        LogFile.logs_from_server(@miq_server.id) rescue nil
      end

      include_examples("Log Collection should create 0 tasks and 0 queue items")
      it { expect(@miq_server).to_not be_log_collection_active }
    end

    context "with error creating queue message" do
      before do
        allow(MiqQueue).to receive(:put).and_raise("some error message")
        LogFile.logs_from_server(@miq_server.id) rescue nil
      end

      include_examples("Log Collection should create 0 tasks and 0 queue items")
      it { expect(@miq_server).to_not be_log_collection_active }
    end
  end

  context "Log Collection #synchronize_logs" do
    before do
      depot = FactoryBot.create(:file_depot)
      @zone.update(:log_file_depot_id => depot.id)
    end

    include_examples("Log Collection #synchronize_logs", "miq_server")
    include_examples("Log Collection #synchronize_logs", "zone")
  end
end
