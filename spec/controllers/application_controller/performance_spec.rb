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
end
