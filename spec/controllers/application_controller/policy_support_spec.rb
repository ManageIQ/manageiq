describe ApplicationController do

  describe "building tabs" do
    before(:each) do
      item = FactoryGirl.create(:vm_vmware)
      session[:tag_db] = VmOrTemplate
      session[:tag_items] = [item]
      controller.instance_variable_set(:@breadcrumbs, [])
    end

    it 'sets the active tab to polsim' do
      controller.send(:policy_sim)
      expect(assigns(:active_tab)).to eq("polsim")
    end

    it 'sets the available tabs' do
      controller.send(:policy_sim)
      expect(assigns(:tabs)).to eq([ ["polsim", "Policy Simulation"] ])
    end
  end
end
