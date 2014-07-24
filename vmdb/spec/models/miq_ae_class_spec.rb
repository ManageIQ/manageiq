require "spec_helper"

describe MiqAeClass do

  it { should belong_to(:ae_namespace) }
  it { should have_many(:ae_fields) }
  it { should have_many(:ae_instances) }
  it { should have_many(:ae_methods) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:namespace_id) }

  it { should allow_value("cla.ss1").for(:name) }
  it { should allow_value("cla-ss1").for(:name) }

  it { should_not allow_value("cla ss1").for(:name) }
  it { should_not allow_value("cla:ss1").for(:name) }

  it "should not create class without namespace" do
    lambda { MiqAeClass.new(:name => "TEST").save! }.should raise_error(ActiveRecord::RecordInvalid)
  end

  it "should not create class without name" do
    lambda { MiqAeClass.new(:namespace => "TEST").save! }.should raise_error(ActiveRecord::RecordInvalid)
  end

  it "should set the updated_by field on save" do
    c1 = MiqAeClass.create(:namespace => "TEST", :name => "oleg")
    c1.updated_by.should == 'system'
  end

  it "should not create classes with the same name in the same namespace" do
    c1 = MiqAeClass.new(:namespace => "TEST", :name => "oleg")
    c1.should_not be_nil
    c1.save!.should be_true
    lambda { MiqAeClass.new(:namespace => "TEST", :name => "OLEG").save! }.should raise_error(ActiveRecord::RecordInvalid)
    c2 = MiqAeClass.new(:namespace => "PROD", :name => "oleg")
    c2.should_not be_nil
    c2.save!.should be_true
  end

  it "should auto-destroy associated records" do
    c1 = MiqAeClass.new(:namespace => "TEST", :name => "test_class")
    c1.should_not be_nil
    c1.save!.should be_true
    c1_id = c1.id
    c1.destroy
    MiqAeField.find_all_by_class_id(c1_id).should be_empty
    MiqAeInstance.find_all_by_class_id(c1_id).should be_empty
    # TODO Check for miq_ae_values
  end

  it "should return editable as false if the parent namespace is not editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10, :system => true)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    c1.should_not be_editable
  end

  it "should return editable as true if the parent namespace is editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1')
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    c1.should be_editable
  end

  context "cross domain instances" do
    def set_priority(name, value)
      ns = MiqAeNamespace.find_by_fqname(name)
      ns.update_attributes!(:priority => value)
    end

    before(:each) do
      model_data_dir = File.join(File.dirname(__FILE__), 'miq_ae_classes')
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain1'), "DOMAIN1")
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain2'), "DOMAIN2")
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain3'), "DOMAIN3")
      set_priority('domain1', 10)
      set_priority('domain2', 20)
      set_priority('domain3', 50)
      @inst4_list =  %w(DOMAIN3/SYSTEM/PROCESS/inst4  DOMAIN1/SYSTEM/PROCESS/inst4)
      @sorted_inst_list =  ['DOMAIN3/SYSTEM/PROCESS/inst1', 'DOMAIN3/SYSTEM/PROCESS/inst2',
                            'DOMAIN3/SYSTEM/PROCESS/inst32', 'DOMAIN3/SYSTEM/PROCESS/inst4',
                            'DOMAIN2/SYSTEM/PROCESS/inst31', 'DOMAIN2/SYSTEM/PROCESS/inst41',
                            'DOMAIN1/SYSTEM/PROCESS/inst3']
    end

    it 'invalid path should return an empty array' do
      MiqAeClass.find_distinct_instances_across_domains('UNKNOWN').should be_empty
      MiqAeClass.find_distinct_instances_across_domains(nil).should be_empty
      MiqAeClass.find_distinct_instances_across_domains('UNKNOWN/').should be_empty
    end

    it 'if the namespace does not exist we should get an empty array' do
      MiqAeClass.find_distinct_instances_across_domains('UNKNOWN/PROCESS').should be_empty
    end

    it 'if the namespace exists but the class does not exist we should get an empty array' do
      MiqAeClass.find_distinct_instances_across_domains('SYSTEM/UNKNOWN').should be_empty
    end

    it 'if the namespace does not exist and the class does not exist we should get an empty array' do
      MiqAeClass.find_distinct_instances_across_domains('UNKNOWN/UNKNOWN').should be_empty
    end

    it 'get sorted list of instances across domains with partial namespace' do
      non_fq_klass = 'SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(non_fq_klass).collect(&:fqname)
      @sorted_inst_list.should match_array(x)
    end

    it 'get sorted list of instances across domains with FQ namespace' do
      fq_klass = 'DOMAIN1/SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(fq_klass).collect(&:fqname)
      @sorted_inst_list.should match_array(x)
    end

    it 'get sorted list of instances across domains with /FQ namespace' do
      fq_klass = '/DOMAIN1/SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(fq_klass).collect(&:fqname)
      @sorted_inst_list.should match_array(x)
    end

    it 'invalid path for similar named instance should return an empty array' do
      MiqAeClass.find_homonymic_instances_across_domains('UNKNOWN').should be_empty
      MiqAeClass.find_homonymic_instances_across_domains(nil).should be_empty
      MiqAeClass.find_homonymic_instances_across_domains('UNKNOWN/').should be_empty
    end

    it 'invalid path no instance specified we should get an empty array' do
      MiqAeClass.find_homonymic_instances_across_domains('UNKNOWN/PROCESS').should be_empty
    end

    it 'if the namespace does not exist but class and instance exist we should get an empty array' do
      MiqAeClass.find_homonymic_instances_across_domains('UNKNOWN/PROCESS/FRED').should be_empty
    end

    it 'if the namespace, instance exists but the class does not exist we should get an empty array' do
      MiqAeClass.find_homonymic_instances_across_domains('SYSTEM/UNKNOWN/FRED').should be_empty
    end

    it 'if the namespace,class, instance does not exist we should get an empty array' do
      MiqAeClass.find_homonymic_instances_across_domains('UNKOWN/UNKNOWN/UNKNOWN').should be_empty
    end

    it 'get sorted list of same named instances across domains with partial namespace' do
      non_fq_inst = 'SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(non_fq_inst).collect(&:fqname)
      @inst4_list.should match_array(x)
    end

    it 'get sorted list of same named instances across domains with FQ namespace' do
      fq_inst = 'DOMAIN1/SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(fq_inst).collect(&:fqname)
      @inst4_list.should match_array(x)
    end

    it 'get sorted list of same named instances across domains with /FQ namespace' do
      fq_inst = '/DOMAIN1/SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(fq_inst).collect(&:fqname)
      @inst4_list.should match_array(x)
    end
  end

  context "#copy" do
    before do
      @d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      @ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => @d1.id)
      @cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => @ns1.id)
      @cls2 = FactoryGirl.create(:miq_ae_class, :name => "cls2", :namespace_id => @ns1.id)

      @d2 = FactoryGirl.create(:miq_ae_namespace,
                               :name      => "domain2",
                               :parent_id => nil,
                               :priority  => 2,
                               :system    => false)
      @ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => @d2.id)
    end

    it "copies classes under specified namespace" do
      domain             = @d2.name
      namespace          = @ns2.name
      overwrite_location = false
      selected_items     = [@cls1.id, @cls2.id]

      res = MiqAeClass.copy(selected_items, domain, namespace, overwrite_location)
      res.count.should eq(2)
    end

    it "copy classes under same namespace raise error when class exists" do
      domain             = @d1.name
      namespace          = @ns1.name
      overwrite_location = false
      selected_items     = [@cls1.id, @cls2.id]

      expect { MiqAeClass.copy(selected_items, domain, namespace, overwrite_location) }.to raise_error(RuntimeError)
    end

    it "replaces classes under same namespace when class exists" do
      domain             = @d2.name
      namespace          = @ns2.name
      selected_items     = [@cls1.id, @cls2.id]
      overwrite_location = true

      res = MiqAeClass.copy(selected_items, domain, namespace, overwrite_location)
      res.count.should eq(2)
    end
  end
end
