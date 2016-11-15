describe ApplicationController do
  context "#perf_planning_gen_data" do
    it "should not get nil error when submitting up Manual Input data" do
      enterprise = FactoryGirl.create(:miq_enterprise)
      allow(MiqServer).to receive(:my_zone).and_return("default")
      sb = HashWithIndifferentAccess.new
      sb[:planning] = {
        :options => {
          :target_typ => "EmsCluster",
          :vm_mode    => :manual,
          :values     => {
            :cpu => 2
          }
        },
        :vm_opts => {
          :cpu => 2
        }
      }
      controller.instance_variable_set(:@sb, sb)
      allow(controller).to receive(:initiate_wait_for_task)
      controller.send(:perf_planning_gen_data)
    end
  end

  describe '#skip_days_from_time_profile' do
    subject { ->(l) { described_class.new.send(:skip_days_from_time_profile, l) } }

    it 'should return empty array for whole week' do
      expect(subject.call((0..6).to_a)).to eq([])
    end

    it 'should return whole week for empty array' do
      expect(subject.call([])).to eq((1..7).to_a)
    end

    it 'should handle Sundays' do
      expect(subject.call((1..6).to_a)).to eq([7])
    end
  end
end
