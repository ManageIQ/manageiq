require "spec_helper"

describe OpsController do
  context "OpsSettings::Schedules" do
    before do
      seed_specific_product_features("ops_explorer")
    end

    context "no schedules selected" do
      before do
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.stub(:find_checked_items).and_return([])
        controller.should_receive(:render)
        controller.should_receive(:schedule_build_list)
        controller.should_receive(:settings_get_info)
        controller.should_receive(:replace_right_cell)
      end

      it "#schedule_enable" do
        controller.schedule_enable
        flash_messages = controller.instance_variable_get(:@flash_array)
        flash_messages.first.should == {:message => "No Schedules were selected to be enabled", :level => :error }
      end

      it "#schedule_disable" do
        controller.schedule_disable
        flash_messages = controller.instance_variable_get(:@flash_array)
        flash_messages.first.should == {:message => "No Schedules were selected to be disabled", :level => :error }
      end
    end

    context "normal case" do
      before do
        server = mock
        server.stub(:zone_id => 1)
        MiqServer.stub(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule, :enabled => true, :updated_at => 1.hour.ago.utc)
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.stub(:find_checked_items).and_return([@sch])
        controller.should_receive(:render).never
        controller.should_receive(:schedule_build_list)
        controller.should_receive(:settings_get_info)
        controller.should_receive(:replace_right_cell)
      end

      it "#schedule_enable" do
        controller.schedule_enable
        controller.send(:flash_errors?).should_not be_true
        @sch.reload
        @sch.should be_enabled
        @sch.updated_at.should be > 10.minutes.ago.utc
      end

      it "#schedule_disable" do
        @sch.update_attribute(:enabled, false)

        controller.schedule_disable
        controller.send(:flash_errors?).should_not be_true
        @sch.reload
        @sch.should_not be_enabled
        @sch.updated_at.should be > 10.minutes.ago.utc
      end
    end
  end
end
