describe "AR Count By Date extension" do
  context "vms with dates" do
    before do
      Timecop.freeze do
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 0.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 1.day.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 2.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 2.days.ago)
        FactoryGirl.create(:vm, :ems_id => 2, :created_on => 2.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 10.days.ago)
        FactoryGirl.create(:vm, :ems_id => 2, :created_on => 10.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 29.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 30.days.ago)
        FactoryGirl.create(:vm, :ems_id => 1, :created_on => 45.days.ago)
      end
    end

    after do
      Timecop.return
    end

    it "returns expected results with default parameters" do
      expect(Vm.recent_records).to eq(
        0.days.ago.strftime('%Y-%m-%d')  => 1,
        1.day.ago.strftime('%Y-%m-%d')   => 1,
        2.days.ago.strftime('%Y-%m-%d')  => 3,
        10.days.ago.strftime('%Y-%m-%d') => 2,
        29.days.ago.strftime('%Y-%m-%d') => 1,
      )
    end

    it "returns expected results for specified date limit" do
      expect(Vm.recent_records(5.days.ago)).to eq(
        0.days.ago.strftime('%Y-%m-%d') => 1,
        1.day.ago.strftime('%Y-%m-%d')  => 1,
        2.days.ago.strftime('%Y-%m-%d') => 3,
      )
    end

    it "returns expected results for specified group by parameter" do
      result = Vm.recent_records(45.days.ago, 'month')
      expect(result[0.months.ago.beginning_of_month.strftime('%Y-%m-%d')]).to be > 0
      expect(result[1.month.ago.beginning_of_month.strftime('%Y-%m-%d')]).to be > 0
    end

    it "returns expected results for specified filter" do
      expect(Vm.recent_records(30.days.ago, 'day', :ems_id => 1)).to eq(
        0.days.ago.strftime('%Y-%m-%d')  => 1,
        1.day.ago.strftime('%Y-%m-%d')   => 1,
        2.days.ago.strftime('%Y-%m-%d')  => 2,
        10.days.ago.strftime('%Y-%m-%d') => 1,
        29.days.ago.strftime('%Y-%m-%d') => 1,
      )
    end
  end
end
