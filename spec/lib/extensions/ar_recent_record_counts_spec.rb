describe "AR Recent Record Counts extension" do
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
      expect(Vm.recent_record_counts).to eq(
        0.days.ago.change(:hour => 0)  => 1,
        1.day.ago.change(:hour => 0)   => 1,
        2.days.ago.change(:hour => 0)  => 3,
        10.days.ago.change(:hour => 0) => 2,
        29.days.ago.change(:hour => 0) => 1,
      )
    end

    it "returns expected results with a formatted date" do
      expect(Vm.recent_record_counts(:key_format => 'YYYY-MM-DD')).to eq(
        0.days.ago.strftime('%Y-%m-%d')  => 1,
        1.day.ago.strftime('%Y-%m-%d')   => 1,
        2.days.ago.strftime('%Y-%m-%d')  => 3,
        10.days.ago.strftime('%Y-%m-%d') => 2,
        29.days.ago.strftime('%Y-%m-%d') => 1,
      )
    end

    it "returns expected results for specified date limit" do
      expect(Vm.recent_record_counts(:date => 5.days.ago, :key_format => 'YYYY-MM-DD')).to eq(
        0.days.ago.strftime('%Y-%m-%d') => 1,
        1.day.ago.strftime('%Y-%m-%d')  => 1,
        2.days.ago.strftime('%Y-%m-%d') => 3,
      )
    end

    it "returns expected results for specified group by parameter" do
      result = Vm.recent_record_counts(:date => 45.days.ago, :group_by => 'month', :key_format => 'YYYY-MM-DD')
      expect(result[0.months.ago.beginning_of_month.strftime('%Y-%m-%d')]).to be > 0
      expect(result[1.month.ago.beginning_of_month.strftime('%Y-%m-%d')]).to be > 0
    end

    it "returns expected results for specified filter" do
      expect(Vm.recent_record_counts(:date => 30.days.ago, :group_by => 'day', :key_format => 'YYYY-MM-DD', :ems_id => 1)).to eq(
        0.days.ago.strftime('%Y-%m-%d')  => 1,
        1.day.ago.strftime('%Y-%m-%d')   => 1,
        2.days.ago.strftime('%Y-%m-%d')  => 2,
        10.days.ago.strftime('%Y-%m-%d') => 1,
        29.days.ago.strftime('%Y-%m-%d') => 1,
      )
    end
  end
end
