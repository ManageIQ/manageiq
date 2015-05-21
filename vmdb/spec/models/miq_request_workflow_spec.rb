require "spec_helper"

describe MiqRequestWorkflow do
  context "#validate" do
    context "validation_method" do
      let(:wf_without_validation) { FactoryGirl.build(:miq_provision_workflow) }
      let(:wf_with_validation)    { FactoryGirl.build(:miq_provision_workflow, :factory_dialog => :miq_dialog_provision_with_validation_method) }

      it "skips validation if no validation_method is defined" do
        expect(wf_without_validation.get_all_dialogs[:customize][:fields][:root_password][:validation_method]).to eq(nil)
        expect(wf_without_validation.validate({})).to be_true
      end

      it "calls the validation_method if defined" do
        wf_with_validation.should_receive(:respond_to?).with(:some_validation_method).and_return(true)
        wf_with_validation.should_receive(:some_validation_method).once
        expect(wf_with_validation.validate({})).to be_true
      end

      it "returns false when validation fails" do
        wf_with_validation.should_receive(:respond_to?).with(:some_validation_method).and_return(true)
        wf_with_validation.should_receive(:some_validation_method).and_return("Some Error")
        expect(wf_with_validation.validate({})).to be_false
      end
    end

    context 'required_method is only run when visible' do
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
        @wf = FactoryGirl.build(:miq_provision_workflow)
        @wf.instance_variable_set("@dialogs", :dialogs => {:customize => @dlg})
      end

      it 'field hidden' do
        expect(@wf.validate(@values)).to be_true
      end

      it 'field visible' do
        @dlg[:fields][:sysprep_organization][:display] = :edit
        expect(@wf).to receive(:validate_sysprep_field).and_return("A validation error")
        expect(@wf.validate(@values)).to be_false
      end
    end
  end
end
