describe PxeController do
  before(:each) do
    set_user_privileges
  end

  describe "#iso_datastore_set_form_vars" do
    it 'assigns form options' do
      FactoryGirl.create(:ems_redhat)
      controller.instance_variable_set(:@isd, FactoryGirl.create(:iso_datastore))
      controller.send(:iso_datastore_set_form_vars)

      expect(assigns(:edit)[:emses]).not_to be_empty
    end
  end
end
