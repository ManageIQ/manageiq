module MiqAeServiceModelSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVm do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @ae_vm = MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.new(@vm.id)
    end

    it ".base_model" do
      expect(MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.base_model).to eq(MiqAeMethodService::MiqAeServiceVm)
    end

    it ".base_class" do
      expect(MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.base_class).to eq(MiqAeMethodService::MiqAeServiceVmOrTemplate)
    end

    it "vm should be valid" do
      expect(@vm).to be_kind_of(Vm)
      expect(@vm).not_to be_nil
      expect(@vm.id).not_to be_nil
    end

    it "ae_vm should be valid" do
      expect(@ae_vm).to be_kind_of(MiqAeMethodService::MiqAeServiceVm)
      expect(@ae_vm.instance_variable_get("@object")).to eq(@vm)
    end

    it "ae_vm should have a special inspect method" do
      inspect = @ae_vm.inspect
      expect(inspect[0, 2]).to eq('#<')
      expect(inspect[-1, 1]).to eq('>')
    end

    it "ae_vm should have an associations method" do
      expect(@ae_vm.associations).to be_kind_of(Array)
    end

    describe "#tag_assign" do
      let(:category)    { FactoryGirl.create(:classification) }
      let(:tag)         { FactoryGirl.create(:classification_tag, :parent_id => category.id) }

      it "can assign an exiting tag to ae_vm" do
        expect(@ae_vm.tag_assign("#{category.name}/#{tag.name}")).to be_truthy
        expect(@ae_vm.tagged_with?(category.name, tag.name)).to be_truthy
      end

      it "cannot assign a non-existing tag to ae_vm, but no error is raised" do
        expect(@ae_vm.tag_assign("#{category.name}/non_exisiting_tag")).to be_truthy
        expect(@ae_vm.tagged_with?(category.name, 'non_exisiting_tag')).to be_falsey
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
          expect(@ae_vm.tag_unassign("#{category.name}/#{tag.name}")).to be_truthy
          expect(@ae_vm.tagged_with?(category.name, tag.name)).to be_falsey
        end

        it "unassigns only specified tag from ae_vm but not other tags from the same category" do
          expect(@ae_vm.tag_assign("#{category.name}/#{another_tag.name}")).to be_truthy

          expect(@ae_vm.tag_unassign("#{category.name}/#{tag.name}")).to be_truthy
          expect(@ae_vm.tagged_with?(category.name, another_tag.name)).to be_truthy
        end
      end

      it "does not raise an error when attempts to unassign a non-existing tag" do
        expect(@ae_vm.tag_unassign("#{category.name}/non_exisiting_tag")).to be_truthy
      end
    end
  end

  describe MiqAeMethodService::MiqAeServiceMiqAeDomain do
    let(:tenant) { Tenant.seed }
    let(:domain) { FactoryGirl.create(:miq_ae_domain, :tenant => tenant) }

    it "#ae_domains" do
      domain
      t = MiqAeMethodService::MiqAeServiceTenant.new(tenant)
      dom = t.ae_domains.first
      [:name, :system, :priority, :id].each do |attr|
        expect(dom.send(attr)).to eql(domain.send(attr))
      end
    end
  end

  describe MiqAeMethodService::MiqAeServiceVmOrTemplate do
    it '#where' do
      vm = FactoryGirl.create(:vm_vmware, :name => 'fred')
      svc_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.where(:name => 'fred').first
      expect(svc_vm.id).to eq(vm.id)
    end
  end

  describe "find_or_create_by" do
    it "blocks" do
      expect do
        MiqAeMethodService::MiqAeServiceVmOrTemplate.find_or_create_by(:name => 'test123')
      end.to raise_error(NoMethodError)
    end
  end

  describe "find_or_initialize_by" do
    it "blocks" do
      expect do
        MiqAeMethodService::MiqAeServiceVmOrTemplate.find_or_initialize_by(:name => 'test123')
      end.to raise_error(NoMethodError)
    end
  end
end
