require "spec_helper"

silence_warnings { MiqProvisionVmwareWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe MiqProvisionVmwareWorkflow do

  before do
    MiqRegion.seed
  end

  context "with a user" do
    let(:admin)    { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }

    before do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
    end

    it "pass platform attributes to automate" do
      MiqAeEngine.should_receive(:resolve_automation_object)
      MiqAeEngine.should_receive(:create_automation_object) do |name, attrs, _options|
        name.should eq("REQUEST")
        attrs.should have_attributes(
          'request'                   => 'UI_PROVISION_INFO',
          'message'                   => 'get_pre_dialog_name',
          'dialog_input_request_type' => 'template',
          'dialog_input_target_type'  => 'vm',
          'platform_category'         => 'infra',
          'platform'                  => 'vmware'
        )
      end

      MiqProvisionVmwareWorkflow.new({}, admin.userid)
    end

    context '#validate' do
      before do
        template = FactoryGirl.create(:template_vmware,
                                      :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication)
        )
        @dlg = {
          :description => 'Customize',
          :fields      => {
            :sysprep_organization => {
              :description     => 'Organization',
              :required_method => :validate_sysprep_field,
              :required        => true,
              :display         => :hide,
              :data_type       => :string,
              :read_only       => true
            }
          },
          :display     => :show
        }
        @values = {
          :src_vm_id            => [template.id, template.name],
          :sysprep_organization => nil,
          :sysprep_enabled      => %w(fields Specification)
        }
        @wf = MiqProvisionVmwareWorkflow.new({}, admin.userid, :src_vm_id => [template.id])
        @wf.instance_variable_set("@dialogs", :dialogs => {:customize => @dlg})
      end

      it 'when hidden' do
        expect(@wf.validate(@values)).to be_true
      end

      it 'when visible' do
        @dlg[:fields][:sysprep_organization][:display] = :edit
        expect(@wf.validate(@values)).to be_false
        expect(@dlg.fetch_path(:fields, :sysprep_organization, :error)).to eq("'Customize/Organization' is required")
      end
    end
  end
end
