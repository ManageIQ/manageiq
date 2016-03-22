describe OpsController do
  describe '#ap_set_record_vars_set' do
    let(:scanitemset) { double }

    context 'missing description' do
      it 'sets scanitemset parameters' do
        expect(scanitemset).to receive(:name=).with('some_name')
        expect(scanitemset).to receive(:description=).with('')
        expect(scanitemset).to receive(:mode=).with(nil)

        subject.instance_variable_set(:@edit, :new => {:name => 'some_name'})

        subject.send(:ap_set_record_vars_set, scanitemset)
      end
    end
  end
  context "#toolbar buttons tests" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      ApplicationController.handle_exceptions = true
    end
    it "add new host analysis profile" do
      session[:sandboxes] = {"ops" => {:active_tree => :settings_tree, :active_tab => "settings_list", :osf_node => "xx-sis", :x_node => "xx-sis"}}
      allow_any_instance_of(OpsController).to receive(:extra_js_commands)
      post :x_button, :pressed => "ap_host_edit", :typ => "Host"
      expect(response.status).to eq(200)
    end

    it "add new vm analysis profile" do
      session[:sandboxes] = {"ops" => {:active_tree => :settings_tree, :active_tab => "settings_list", :osf_node => "xx-sis", :x_node => "xx-sis"}}
      allow_any_instance_of(OpsController).to receive(:extra_js_commands)
      post :x_button, :pressed => "ap_vm_edit", :typ => "Host"
      expect(response.status).to eq(200)
    end
  end
end
