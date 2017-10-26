describe MiqBulkImport do
  context AssetTagImport do
    before do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe")
    end

    it ".upload with no vms" do
      ati = AssetTagImport.upload('VmOrTemplate', @file)
      expect(ati.stats[:bad]).to eq(1)
      expect(ati.stats[:good]).to eq(0)
      ati.errors.all? { |attr,| expect(attr.to_s).to eq('vmortemplatenotfound') }
    end

    it ".upload" do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe\nJD-C-T4.0.1.43,Jerry")
      FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")

      ati = AssetTagImport.upload('VmOrTemplate', @file)
      expect(ati.stats[:good]).to eq(2)
    end

    it "#apply" do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe\nJD-C-T4.0.1.43,Jerry")
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      template = FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ati = AssetTagImport.upload('VmOrTemplate', @file)
      ati.apply

      vm.reload
      expect(vm.custom_attributes.first.name).to eq('owner')
      expect(vm.custom_attributes.first.value).to eq('Joe')

      template.reload
      expect(template.custom_attributes.first.name).to eq('owner')
      expect(template.custom_attributes.first.value).to eq('Jerry')
    end
  end

  context ClassificationImport do
    before do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test")
    end

    it ".upload with no vms" do
      ci = ClassificationImport.upload(@file)
      expect(ci.stats[:bad]).to eq(1)
      expect(ci.stats[:good]).to eq(0)
      ci.errors.all? { |attr,| expect(attr.to_s).to eq('vmnotfound') }
    end

    it ".upload with no category" do
      FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      ci = ClassificationImport.upload(@file)
      expect(ci.stats[:bad]).to eq(1)
      expect(ci.stats[:good]).to eq(0)
      ci.errors.all? { |attr,| expect(attr.to_s).to eq('categorynotfound') }
    end

    it ".upload" do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test\nJD-C-T4.0.1.43,Environment,Test")
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      FactoryGirl.create(:classification, :parent_id => category.id, :name => 'test', :description => 'Test')
      FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ci = ClassificationImport.upload(@file)
      expect(ci.stats[:bad]).to eq(0)
      expect(ci.stats[:good]).to eq(2)
      expect(ci.errors).to be_empty
    end

    it "#apply" do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test\nJD-C-T4.0.1.43,Environment,Test")
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      FactoryGirl.create(:classification, :parent_id => category.id, :name => 'test', :description => 'Test')
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      template = FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ci = ClassificationImport.upload(@file)
      ci.apply

      vm.reload
      expect(vm.is_tagged_with?("test", :cat => "environment", :ns => "/managed")).to be_truthy

      template.reload
      expect(template.is_tagged_with?("test", :cat => "environment", :ns => "/managed")).to be_truthy
    end
  end
end
