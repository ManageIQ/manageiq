require "spec_helper"

describe MiqProvisionVirtWorkflow do
  context "#continue_request" do
    let(:sdn)      { "SysprepDomainName" }
    let(:workflow) { FactoryGirl.create(:miq_provision_virt_workflow) }

    before do
      FactoryGirl.create(:user_admin)
      FactoryGirl.create(:miq_dialog_provision)
      workflow.stub(:validate => true)
      workflow.stub(:get_dialogs => {})
      workflow.instance_variable_set(:@values, {:vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields', :sysprep_domain_name => sdn})
    end

    context "exit_pre_dialog" do
      it "doesn't exit when not running" do
        workflow.should_not_receive(:exit_pre_dialog)

        expect(workflow.continue_request({}, nil)).to be_true
      end

      it "exits when running" do
        workflow.instance_variable_set(:@running_pre_dialog, true)
        new_values = workflow.instance_variable_get(:@values)

        workflow.should_receive(:exit_pre_dialog).once.and_call_original

        expect(workflow.continue_request({}, nil)).to                   be_true
        expect(workflow.instance_variable_get(:@last_vm_id)).to         eq(123)
        expect(workflow.instance_variable_get(:@running_pre_dialog)).to be_false
        expect(workflow.instance_variable_get(:@tags)).to               be_nil
        expect(new_values[:forced_sysprep_enabled]).to                  eq('fields')
        expect(new_values[:forced_sysprep_domain_name]).to              eq([sdn])
        expect(new_values[:sysprep_domain_name]).to                     eq([sdn, sdn])
        expect(new_values[:vm_tags]).to                                 be_kind_of(Array)
      end
    end
  end
end
