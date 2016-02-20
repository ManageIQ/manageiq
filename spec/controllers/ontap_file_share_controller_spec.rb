describe OntapFileShareController do
  context "#process_button" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "when VM Right Size Recommendations is pressed" do
      expect(controller).to receive(:vm_right_size)
      post :button, :params => { :pressed => "vm_right_size", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      expect(controller).to receive(:prov_redirect).with("migrate")
      post :button, :params => { :pressed => "vm_migrate", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Retire is pressed" do
      expect(controller).to receive(:retirevms).once
      post :button, :params => { :pressed => "vm_retire", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => "vm_protect", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => "miq_template_protect", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => "vm_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => "miq_template_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Host Analyze then Check Compliance is pressed" do
      allow(controller).to receive(:show)
      expect(controller).to receive(:analyze_check_compliance_hosts)
      post :button, :params => { :pressed => "host_analyze_check_compliance", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end
end
