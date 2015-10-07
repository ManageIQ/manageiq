require "spec_helper"

module MiqAeServiceModelSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVm do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @ae_vm = MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.new(@vm.id)
    end

    it ".base_model" do
      MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.base_model.should == MiqAeMethodService::MiqAeServiceVm
    end

    it ".base_class" do
      MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.base_class.should == MiqAeMethodService::MiqAeServiceVmOrTemplate
    end

    it "vm should be valid" do
      @vm.should be_kind_of(Vm)
      @vm.should_not be_nil
      @vm.id.should_not be_nil
    end

    it "ae_vm should be valid" do
      @ae_vm.should be_kind_of(MiqAeMethodService::MiqAeServiceVm)
      @ae_vm.instance_variable_get("@object").should == @vm
    end

    it "ae_vm should have a special inspect method" do
      inspect = @ae_vm.inspect
      inspect[0, 2].should == '#<'
      inspect[-1, 1].should == '>'
    end

    it "ae_vm should have an associations method" do
      @ae_vm.associations.should be_kind_of(Array)
    end

    describe "#tag_assign" do
      let(:category)    { FactoryGirl.create(:classification) }
      let(:tag)         { FactoryGirl.create(:classification_tag, :parent_id => category.id) }

      it "can assign an exiting tag to ae_vm" do
        @ae_vm.tag_assign("#{category.name}/#{tag.name}").should be_true
        @ae_vm.tagged_with?(category.name, tag.name).should be_true
      end

      it "cannot assign a non-existing tag to ae_vm, but no error is raised" do
        @ae_vm.tag_assign("#{category.name}/non_exisiting_tag").should be_true
        @ae_vm.tagged_with?(category.name, 'non_exisiting_tag').should be_false
      end
    end

    describe "#tag_unassign" do
      let(:category)    { FactoryGirl.create(:classification) }
      let(:tag)         { FactoryGirl.create(:classification_tag, :parent_id => category.id) }
      let(:another_tag) { FactoryGirl.create(:classification_tag, :parent_id => category.id) }

      context "with assigned tags" do
        before do
          @ae_vm.tag_assign("#{category.name}/#{tag.name}")
        end

        it "can unassign a tag from ae_vm" do
          @ae_vm.tag_unassign("#{category.name}/#{tag.name}").should be_true
          @ae_vm.tagged_with?(category.name, tag.name).should be_false
        end

        it "unassigns only specified tag from ae_vm but not other tags from the same category" do
          @ae_vm.tag_assign("#{category.name}/#{another_tag.name}").should be_true

          @ae_vm.tag_unassign("#{category.name}/#{tag.name}").should be_true
          @ae_vm.tagged_with?(category.name, another_tag.name).should be_true
        end
      end

      it "does not raise an error when attempts to unassign a non-existing tag" do
        @ae_vm.tag_unassign("#{category.name}/non_exisiting_tag").should be_true
      end
    end
  end
end
