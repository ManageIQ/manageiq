require "spec_helper"

describe MiqReportResult do
  context "::Purging" do
    before(:each) do
      @vmdb_config = {
        :reporting => {
          :history => {
            :keep_reports      => "6.months",
            :purge_window_size => 100
          }
        }
      }
      VMDB::Config.any_instance.stub(:config).and_return(@vmdb_config)

      @rr1 = [
        FactoryGirl.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months + 1.days).to_i.ago.utc),
        FactoryGirl.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months - 1.days).to_i.ago.utc)
      ]
      @rr2 = [
        FactoryGirl.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 2.days).to_i.ago.utc),
        FactoryGirl.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 1.days).to_i.ago.utc),
        FactoryGirl.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months - 1.days).to_i.ago.utc)
      ]
      @rr_orphaned = [
        FactoryGirl.create(:miq_report_result, :miq_report_id => nil, :created_on => (6.months - 1.days).to_i.ago.utc)
      ]
    end

    context "#purge_mode_and_value" do
      it "with missing config value" do
        @vmdb_config.delete_path(:reporting, :history, :keep_reports)
        Timecop.freeze(Time.now) do
          described_class.purge_mode_and_value.should == [:date, 6.months.to_i.ago.utc]
        end
      end

      it "with date" do
        @vmdb_config.store_path(:reporting, :history, :keep_reports, "1.day")
        Timecop.freeze(Time.now) do
          described_class.purge_mode_and_value.should == [:date, 1.day.to_i.ago.utc]
        end
      end

      it "with count" do
        @vmdb_config.store_path(:reporting, :history, :keep_reports, 50)
        described_class.purge_mode_and_value.should == [:remaining, 50]
      end
    end

    context "#purge_window_size" do
      it "with missing config value" do
        @vmdb_config.delete_path(:reporting, :history, :purge_window_size)
        Timecop.freeze(Time.now) do
          described_class.purge_window_size.should == 100
        end
      end

      it "with value" do
        @vmdb_config.store_path(:reporting, :history, :purge_window_size, 1000)
        Timecop.freeze(Time.now) do
          described_class.purge_window_size.should == 1000
        end
      end
    end

    it "#purge_timer" do
      EvmSpecHelper.seed_for_miq_queue

      Timecop.freeze(Time.now) do
        described_class.purge_timer

        q = MiqQueue.all
        q.length.should == 1
        q.first.should have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge"
        )

        q.first.args[0].should == :date
        q.first.args[1].should be_same_time_as 6.months.to_i.ago.utc
      end
    end

    context "#purge_queue" do
      before(:each) do
        EvmSpecHelper.seed_for_miq_queue
        described_class.purge_queue(:remaining, 1)
      end

      it "with nothing in the queue" do
        q = MiqQueue.all
        q.length.should == 1
        q.first.should have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge",
          :args        => [:remaining, 1]
        )
      end

      it "with item already in the queue" do
        described_class.purge_queue(:remaining, 2)

        q = MiqQueue.all
        q.length.should == 1
        q.first.should have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge",
          :args        => [:remaining, 2]
        )
      end
    end

    it "#purge_ids_for_remaining" do
      described_class.send(:purge_ids_for_remaining, 1).should == {1 => @rr1.last.id, 2 => @rr2.last.id}
    end

    it "#purge_counts_for_remaining" do
      described_class.send(:purge_counts_for_remaining, 1).should == {1 => 1, 2 => 2}
    end

    context "#purge_count" do
      it "by remaining" do
        described_class.purge_count(:remaining, 1).should == 3
      end

      it "by date" do
        described_class.purge_count(:date, 6.months.to_i.ago.utc).should == 3
      end
    end

    context "#purge" do
      it "by remaining" do
        described_class.purge(:remaining, 1)
        described_class.where(:miq_report_id => 1).all.should   == [@rr1.last]
        described_class.where(:miq_report_id => 2).all.should   == [@rr2.last]
        described_class.where(:miq_report_id => nil).all.should == @rr_orphaned
      end

      it "by date" do
        described_class.purge(:date, 6.months.to_i.ago.utc)
        described_class.where(:miq_report_id => 1).all.should   == [@rr1.last]
        described_class.where(:miq_report_id => 2).all.should   == [@rr2.last]
        described_class.where(:miq_report_id => nil).all.should == @rr_orphaned
      end
    end
  end
end
