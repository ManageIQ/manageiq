require "support/controller_spec_helper"

describe MiqRequestController do
  describe "#dialog_partial_for_workflow" do
    before do
      @wf = FactoryGirl.create(:miq_provision_virt_workflow)
    end

    it "calculates partial using wf from @edit hash" do
      controller.instance_variable_set(:@edit, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @options hash" do
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @options hash when user is on approve/deny form screen" do
      controller.instance_variable_set(:@edit, :stamp_typ => 'a')
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @edit hash when both @edit & @options are present" do
      controller.instance_variable_set(:@edit, :wf => FactoryGirl.create(:miq_provision_configured_system_foreman_workflow))
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('prov_configured_system_foreman_dialog')
    end

    it "clears the request datacenter name field when the source VM is changed" do
      datacenter = FactoryGirl.create(:datacenter, :name => 'dcname')
      ems_folder = FactoryGirl.create(:ems_folder)
      ems = FactoryGirl.create(:ems_vmware)
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)
      datacenter.ext_management_system = ems
      ems_folder.ext_management_system = ems
      @wf.instance_variable_set(:@dialogs, :dialogs => {:environment => {:fields => {:placement_dc_name => {:values => {datacenter.id.to_s => datacenter.name}}}}})
      controller.instance_variable_set(:@edit, :wf => @wf, :new => {:src_vm_id => vm1.id.to_s})
      controller.instance_variable_set(:@last_vm_id, vm2.id)
      controller.instance_variable_set(:@_params, 'service__src_vm_id' => vm1.id, :id => "new", :controller => "miq_request")
      @wf.instance_variable_set(:@values, :placement_dc_name=>[datacenter.id.to_s, datacenter.name])
      edit = {:wf => @wf, :new => {:placement_dc_name => [datacenter.id, datacenter.name]}}
      @wf.instance_variable_set(:@edit, edit)
      allow(controller).to receive(:load_edit).and_return(true)
      allow(controller).to receive(:render).and_return(true)
      allow(@wf).to receive(:get_field).and_return(:values => {:placement_dc_name=>[datacenter.id.to_s, datacenter.name]})
      controller.send(:prov_field_changed)
      values = @wf.instance_variable_get(:@values)
      expect(values.to_s).to_not include('dcname')
    end
  end

  describe '#prov_edit' do
    it 'redirects to the last link in breadcrumbs' do
      allow_any_instance_of(described_class).to receive(:set_user_time_zone)
      session[:edit] = {}
      controller.instance_variable_set(:@breadcrumbs, [{:url => "/ems_infra/show_list?page=1&refresh=y"},
                                                       {:url => "/ems_infra/1000000000001?display=vms"},
                                                       {}])
      controller.instance_variable_set(:@_params, :id => "new", :button => "cancel")
      allow(controller).to receive(:role_allows).and_return(true)
      page = double('page')
      allow(page).to receive(:<<).with(any_args)
      expect(page).to receive(:redirect_to).with("/ems_infra/1000000000001?display=vms")
      expect(controller).to receive(:render).with(:update).and_yield(page)
      controller.send(:prov_edit)
    end
  end
end
