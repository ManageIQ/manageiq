require "spec_helper"

describe MiqBulkImport do
  context AssetTagImport do
    before do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe")
    end

    it ".upload with no vms" do
      ati = AssetTagImport.upload('VmOrTemplate', @file)
      ati.stats[:bad].should == 1
      ati.stats[:good].should == 0
      ati.errors.all? { |attr,| attr.to_s.should == 'vmortemplatenotfound'}
    end

    it ".upload" do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe\nJD-C-T4.0.1.43,Jerry")
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      template = FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")

      ati = AssetTagImport.upload('VmOrTemplate', @file)
      ati.stats[:good].should == 2
    end

    it "#apply" do
      @file = StringIO.new("name,owner\nJD-C-T4.0.1.44,Joe\nJD-C-T4.0.1.43,Jerry")
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      template = FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ati = AssetTagImport.upload('VmOrTemplate', @file)
      ati.apply

      vm.reload
      vm.custom_attributes.first.name.should == 'owner'
      vm.custom_attributes.first.value.should == 'Joe'

      template.reload
      template.custom_attributes.first.name.should == 'owner'
      template.custom_attributes.first.value.should == 'Jerry'
    end
  end

  context ClassificationImport do
    before do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test")
    end

    it ".upload with no vms" do
      ci = ClassificationImport.upload(@file)
      ci.stats[:bad].should == 1
      ci.stats[:good].should == 0
      ci.errors.all? { |attr,| attr.to_s.should == 'vmnotfound' }
    end

    it ".upload with no category" do
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      ci = ClassificationImport.upload(@file)
      ci.stats[:bad].should == 1
      ci.stats[:good].should == 0
      ci.errors.all? { |attr,| attr.to_s.should == 'categorynotfound' }
    end

    it ".upload" do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test\nJD-C-T4.0.1.43,Environment,Test")
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      entry = FactoryGirl.create(:classification, :parent_id => category.id, :name => 'test', :description => 'Test')
      FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ci = ClassificationImport.upload(@file)
      ci.stats[:bad].should == 0
      ci.stats[:good].should == 2
      ci.errors.should be_empty
    end

    it "#apply" do
      @file = StringIO.new("name,category,entry\nJD-C-T4.0.1.44,Environment,Test\nJD-C-T4.0.1.43,Environment,Test")
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      entry = FactoryGirl.create(:classification, :parent_id => category.id, :name => 'test', :description => 'Test')
      vm = FactoryGirl.create(:vm_vmware, :name => "JD-C-T4.0.1.44")
      template = FactoryGirl.create(:template_vmware, :name => "JD-C-T4.0.1.43")
      ci = ClassificationImport.upload(@file)
      ci.apply

      vm.reload
      vm.is_tagged_with?("test", :cat => "environment", :ns => "/managed").should be_true

      template.reload
      template.is_tagged_with?("test", :cat => "environment", :ns => "/managed").should be_true
    end
  end
end
