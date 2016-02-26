describe EmsClusterController do
  context "#button" do
    it "when VM Right Size Recommendations is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_right_size")
      expect(controller).to receive(:vm_right_size)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate button is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_migrate")
      controller.instance_variable_set(:@refresh_partial, "layouts/gtl")
      expect(controller).to receive(:prov_redirect).with("migrate")
      expect(controller).to receive(:render)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Retire button is pressed" do
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
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @cluster = FactoryGirl.create(:ems_cluster)
      @user = FactoryGirl.create(:user)
      login_as @user
    end

    subject do
      get :show, :id => @cluster.id
    end

    context "render listnav partial" do
      render_views
      it { is_expected.to have_http_status 200 }
      it { is_expected.to render_template(:partial => "layouts/listnav/_ems_cluster") }
    end
  end
end
