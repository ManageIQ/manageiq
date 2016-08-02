describe PxeController do
  before do
    stub_user(:features => :all)
  end

  describe "#iso_datastore_set_form_vars" do
    context "when EMS is available" do
      before do
        @ems = FactoryGirl.create(:ems_redhat)
        iso = FactoryGirl.create(:iso_datastore)
        controller.instance_variable_set(:@isd, iso)
      end

      it 'includes ems in form options' do
        controller.send(:iso_datastore_set_form_vars)
        expect(assigns(:edit)[:emses]).to eq([[@ems.name, @ems.id]])
      end
    end

    context "when EMS is not available" do
      before do
        ems = FactoryGirl.create(:ems_redhat)
        iso = FactoryGirl.create(:iso_datastore, :ems_id => ems.id)
        controller.instance_variable_set(:@isd, iso)
      end

      it 'does not include ems in form options' do
        controller.send(:iso_datastore_set_form_vars)
        expect(assigns(:edit)[:emses]).to eq([])
      end
    end
  end
end
