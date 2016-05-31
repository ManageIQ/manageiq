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
