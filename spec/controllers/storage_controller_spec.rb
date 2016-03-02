describe StorageController do
  context "#button" do
    it "when VM Right Size Recommendations is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_right_size")
      expect(controller).to receive(:vm_right_size)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_migrate")
      controller.instance_variable_set(:@refresh_partial, "layouts/gtl")
      expect(controller).to receive(:prov_redirect).with("migrate")
      expect(controller).to receive(:render)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Retire is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_retire")
      expect(controller).to receive(:retirevms).once
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_protect")
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_protect"})
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Tag is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_tag")
      expect(controller).to receive(:tag).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Tag is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "miq_template_tag")
      expect(controller).to receive(:tag).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Host Analyze then Check Compliance is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "host_analyze_check_compliance")
      allow(controller).to receive(:show)
      expect(controller).to receive(:analyze_check_compliance_hosts)
      expect(controller).to receive(:render)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    {"host_standby"  => "Enter Standby Mode",
     "host_shutdown" => "Shut Down",
     "host_reboot"   => "Restart",
     "host_start"    => "Power On",
     "host_stop"     => "Power Off",
     "host_reset"    => "Reset"
    }.each do |button, description|
      it "when Host #{description} button is pressed" do
        login_as FactoryGirl.create(:user, :features => button)

        host = FactoryGirl.create(:host)
        command = button.split('_', 2)[1]
        allow_any_instance_of(Host).to receive(:is_available?).with(command).and_return(true)

        controller.instance_variable_set(:@_params, :pressed => button, :miq_grid_checks => "#{host.id}")
        controller.instance_variable_set(:@lastaction, "show_list")
        allow(controller).to receive(:show_list)
        expect(controller).to receive(:render)
        controller.button
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("successfully initiated")
        expect(flash_messages.first[:level]).to eq(:success)
      end
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @user = FactoryGirl.create(:user)
      login_as @user
      session[:settings] = {:views => {:vm_summary_cool => "summary"}}
      @storage = FactoryGirl.create(:storage)
    end

    subject { get :show, :id => @storage.id }

    context "render" do
      render_views
      it "listnav" do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_storage")
      end
    end
  end
end
