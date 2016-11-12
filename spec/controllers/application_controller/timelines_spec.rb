describe ApplicationController, "#Timelines" do
  describe EmsInfraController do
    context "#tl_chooser" do
      it "resets timeline options correctly when apply button is pressed" do
        ems = FactoryGirl.create(:ems_openstack_infra)
        controller.instance_variable_set(:@tl_options,
                                         ApplicationController::Timelines::Options.new)
        options            = assigns(:tl_options)
        dt                 = Time.zone.now
        options.date       = ApplicationController::Timelines::DateOptions.new
        options.date.end   = dt
        options.date.start = dt

        controller.instance_variable_set(:@_params, :id => ems.id, :tl_show => "policy_timeline")
        expect(controller).to receive(:render)

        expect(options.date[:start]).to eq(dt)
        expect(options.date[:end]).to eq(dt)

        controller.send(:tl_chooser)

        options = assigns(:tl_options)
        expect(options.date[:start]).to eq(nil)
        expect(options.date[:end]).to eq(nil)
      end
    end
  end
end
