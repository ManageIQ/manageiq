require "spec_helper"

describe OpsController do
  context "OpsSettings::Schedules" do
    before do
      seed_specific_product_features("schedule_enable", "schedule_disable")
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
        server = double
        server.stub(:zone_id => 1)
        MiqServer.stub(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule)
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.params["check_#{controller.to_cid(@sch.id)}"] = '1'
        controller.should_receive(:render).never
        controller.should_receive(:schedule_build_list)
        controller.should_receive(:settings_get_info)
        controller.should_receive(:replace_right_cell)
      end

      it "doesn't update schedules that don't change" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_disable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's disabled
        @sch.should_not be_enabled
      end

      it "#schedule_enable" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_enable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's enabled
        @sch.should be_enabled
      end

      it "#schedule_disable" do
        # set it to enabled
        @sch.update_attribute(:enabled, true)

        # disable the schedule and save it
        controller.schedule_disable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's disabled
        @sch.should_not be_enabled
      end
    end
  end
end
