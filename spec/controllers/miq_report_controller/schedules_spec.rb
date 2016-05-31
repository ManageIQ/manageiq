describe ReportController, "::Schedules" do
  let(:user) { FactoryGirl.create(:user, :features => %w(miq_report_schedule_delete)) }

  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
    login_as(user)
  end

  describe "#miq_report_schedule_delete" do
    before(:each) do
      allow(controller).to receive(:x_node=)
      allow(controller).to receive(:replace_right_cell)
      allow(controller).to receive(:find_checked_items).and_return(schedules)
    end

    context 'deleting a single schedule' do
      let(:schedule) { FactoryGirl.create(:miq_schedule) }
      let(:schedules) { [schedule] }

      it 'returns with the name of the schedule in the flash' do
        controller.send(:miq_report_schedule_delete)
        expect(assigns(:flash_array)).to eq([{:message => "Schedule #{schedule.name} was deleted", :level => :success}])
      end
    end

    context 'deleting multiple schedules' do
      let(:schedule1) { FactoryGirl.create(:miq_schedule) }
      let(:schedule2) { FactoryGirl.create(:miq_schedule) }
      let(:schedules) { [schedule1, schedule2] }

      it 'returns with a plural form in the flash' do
        controller.send(:miq_report_schedule_delete)
        expect(assigns(:flash_array)).to eq([{:message => "The selected Schedules were deleted", :level => :success}])
      end
    end
  end
end
