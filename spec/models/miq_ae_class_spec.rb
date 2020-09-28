RSpec.describe MiqAeClass do
  include Spec::Support::AutomationHelper

  it "doesn’t access database when unchanged model is saved" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
    n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    expect { c1.valid? }.not_to make_database_queries
  end

  describe "name attribute validation" do
    let(:ns) { FactoryBot.create(:miq_ae_namespace) }
    subject { described_class.new(:ae_namespace => ns) }

    example "with no name" do
      subject.name = nil
      subject.valid?
      expect(subject.errors[:name]).to be_present
    end

    example "with no namespace_id" do
      subject.namespace_id = nil
      subject.valid?
      expect(subject.errors[:namespace_id]).to be_present
    end

    example "with a valid name" do
      subject.name = "cla.ss1"
      subject.valid?
      expect(subject.errors[:name]).to be_blank

      subject.name = "cla-ss1"
      subject.valid?
      expect(subject.errors[:name]).to be_blank
    end

    example "with an invalid name" do
      subject.name = "cla ss1"
      subject.valid?
      expect(subject.errors[:name]).to be_present

      subject.name = "cla:ss1"
      subject.valid?
      expect(subject.errors[:name]).to be_present
    end
  end

  before do
    @user = FactoryBot.create(:user_with_group)
    @ns = FactoryBot.create(:miq_ae_namespace, :name => "TEST", :parent => FactoryBot.create(:miq_ae_domain))
  end

  it "should not create class without namespace" do
    expect { MiqAeClass.new(:name => "TEST").save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should not create class without name" do
    expect { MiqAeClass.new(:namespace_id => @ns.id).save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should set the updated_by field on save" do
    c1 = MiqAeClass.create(:namespace_id => @ns.id, :name => "oleg")
    expect(c1.updated_by).to eq('system')
  end

  it "should not create classes with the same name in the same namespace" do
    c1 = MiqAeClass.new(:namespace_id => @ns.id, :name => "oleg")
    expect(c1).not_to be_nil
    expect(c1.save!).to be_truthy
    expect { MiqAeClass.new(:namespace_id => @ns.id, :name => "OLEG").save! }.to raise_error(ActiveRecord::RecordInvalid)
    n2 = FactoryBot.create(:miq_ae_namespace, :parent => FactoryBot.create(:miq_ae_domain))
    c2 = MiqAeClass.new(:namespace_id => n2.id, :name => "oleg")
    expect(c2).not_to be_nil
    expect(c2.save!).to be_truthy
  end

  it "should return editable as false if the parent namespace is not editable" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
    n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    expect(c1.editable?(@user)).to be_falsey
  end

  it "should return editable as true if the parent namespace is editable" do
    d1 = FactoryBot.create(:miq_ae_domain, :tenant => @user.current_tenant)
    n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    expect(c1.editable?(@user)).to be_truthy
  end

  context "cross domain instances" do
    def set_priority(name, value)
      ns = MiqAeNamespace.lookup_by_fqname(name)
      ns.update!(:priority => value)
    end

    before do
      @user = FactoryBot.create(:user_with_group, 'name' => 'Fred')
      model_data_dir = Rails.root.join("spec/models/miq_ae_class/data")
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain1'), "DOMAIN1")
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain2'), "DOMAIN2")
      EvmSpecHelper.import_yaml_model(File.join(model_data_dir, 'domain3'), "DOMAIN3")
      set_priority('domain1', 10)
      set_priority('domain2', 20)
      set_priority('domain3', 50)
      @inst4_list =  %w(/DOMAIN3/SYSTEM/PROCESS/inst4  /DOMAIN1/SYSTEM/PROCESS/inst4)
      @sorted_inst_list =  ['/DOMAIN3/SYSTEM/PROCESS/inst1', '/DOMAIN3/SYSTEM/PROCESS/inst2',
                            '/DOMAIN3/SYSTEM/PROCESS/inst32', '/DOMAIN3/SYSTEM/PROCESS/inst4',
                            '/DOMAIN2/SYSTEM/PROCESS/inst31', '/DOMAIN2/SYSTEM/PROCESS/inst41',
                            '/DOMAIN1/SYSTEM/PROCESS/inst3']
    end

    it 'invalid path should return an empty array' do
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, 'UNKNOWN')).to be_empty
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, nil)).to be_empty
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, 'UNKNOWN/')).to be_empty
    end

    it 'if the namespace does not exist we should get an empty array' do
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, 'UNKNOWN/PROCESS')).to be_empty
    end

    it 'if the namespace exists but the class does not exist we should get an empty array' do
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, 'SYSTEM/UNKNOWN')).to be_empty
    end

    it 'if the namespace does not exist and the class does not exist we should get an empty array' do
      expect(MiqAeClass.find_distinct_instances_across_domains(@user, 'UNKNOWN/UNKNOWN')).to be_empty
    end

    it 'get sorted list of instances across domains with partial namespace' do
      non_fq_klass = 'SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(@user, non_fq_klass).collect(&:fqname)
      expect(@sorted_inst_list).to match_string_array_ignorecase(x)
    end

    it 'get sorted list of instances across domains with FQ namespace' do
      fq_klass = 'DOMAIN1/SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(@user, fq_klass).collect(&:fqname)
      expect(@sorted_inst_list).to match_string_array_ignorecase(x)
    end

    it 'get sorted list of instances across domains with /FQ namespace' do
      fq_klass = '/DOMAIN1/SYSTEM/PROCESS'
      x = MiqAeClass.find_distinct_instances_across_domains(@user, fq_klass).collect(&:fqname)
      expect(@sorted_inst_list).to match_string_array_ignorecase(x)
    end

    it 'invalid path for similar named instance should return an empty array' do
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'UNKNOWN')).to be_empty
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, nil)).to be_empty
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'UNKNOWN/')).to be_empty
    end

    it 'invalid path no instance specified we should get an empty array' do
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'UNKNOWN/PROCESS')).to be_empty
    end

    it 'if the namespace does not exist but class and instance exist we should get an empty array' do
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'UNKNOWN/PROCESS/FRED')).to be_empty
    end

    it 'if the namespace, instance exists but the class does not exist we should get an empty array' do
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'SYSTEM/UNKNOWN/FRED')).to be_empty
    end

    it 'if the namespace,class, instance does not exist we should get an empty array' do
      expect(MiqAeClass.find_homonymic_instances_across_domains(@user, 'UNKOWN/UNKNOWN/UNKNOWN')).to be_empty
    end

    it 'get sorted list of same named instances across domains with partial namespace' do
      non_fq_inst = 'SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(@user, non_fq_inst).collect(&:fqname)
      expect(@inst4_list).to match_string_array_ignorecase(x)
    end

    it 'get sorted list of same named instances across domains with FQ namespace' do
      fq_inst = 'DOMAIN1/SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(@user, fq_inst).collect(&:fqname)
      expect(@inst4_list).to match_string_array_ignorecase(x)
    end

    it 'get sorted list of same named instances across domains with /FQ namespace' do
      fq_inst = '/DOMAIN1/SYSTEM/PROCESS/Inst4'
      x = MiqAeClass.find_homonymic_instances_across_domains(@user, fq_inst).collect(&:fqname)
      expect(@inst4_list).to match_string_array_ignorecase(x)
    end
  end

  context "#copy" do
    before do
      @d1 = FactoryBot.create(:miq_ae_domain, :name => "domain1", :parent => nil, :priority => 1)
      @ns1 = FactoryBot.create(:miq_ae_namespace, :name => "ns1", :parent => @d1)
      @cls1 = FactoryBot.create(:miq_ae_class, :name => "cls1", :namespace_id => @ns1.id)
      @cls2 = FactoryBot.create(:miq_ae_class, :name => "cls2", :namespace_id => @ns1.id)

      @d2 = FactoryBot.create(:miq_ae_domain, :name => "domain2", :priority  => 2)
      @ns2 = FactoryBot.create(:miq_ae_namespace, :name => "ns2", :parent => @d2)
    end

    it "copies classes under specified namespace" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => false,
        :ids                => [@cls1.id, @cls2.id]
      }

      res = MiqAeClass.copy(options)
      expect(res.count).to eq(2)
    end

    it "copy classes under same namespace raise error when class exists" do
      options = {
        :domain             => @d1.name,
        :namespace          => @ns1.name,
        :overwrite_location => false,
        :ids                => [@cls1.id, @cls2.id]
      }

      expect { MiqAeClass.copy(options) }.to raise_error(RuntimeError)
    end

    it "replaces classes under same namespace when class exists" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => true,
        :ids                => [@cls1.id, @cls2.id]
      }

      res = MiqAeClass.copy(options)
      expect(res.count).to eq(2)
    end
  end

  describe "#to_export_xml" do
    let(:miq_ae_class) do
      described_class.new(
        :ae_fields    => ae_fields,
        :ae_instances => [ae_instance1, ae_instance2],
        :ae_methods   => [ae_method1, ae_method2],
        :created_on   => Time.zone.now,
        :id           => 123,
        :namespace_id => 321,
        :updated_by   => "me",
        :updated_on   => Time.zone.now
      )
    end

    let(:ae_method1) { MiqAeMethod.new }
    let(:ae_method2) { MiqAeMethod.new }

    let(:ae_instance1) { MiqAeInstance.new }
    let(:ae_instance2) { MiqAeInstance.new }

    before do
      allow(ae_method1).to receive(:fqname).and_return("z")
      allow(ae_method2).to receive(:fqname).and_return("a")
      allow(ae_method1).to receive(:to_export_xml) { |options| options[:builder].ae_method1 }
      allow(ae_method2).to receive(:to_export_xml) { |options| options[:builder].ae_method2 }

      allow(ae_instance1).to receive(:fqname).and_return("z")
      allow(ae_instance2).to receive(:fqname).and_return("a")
      allow(ae_instance1).to receive(:to_export_xml) { |options| options[:builder].ae_instance1 }
      allow(ae_instance2).to receive(:to_export_xml) { |options| options[:builder].ae_instance2 }
    end

    context "when the class has ae_fields" do
      let(:ae_fields) { [ae_field1, ae_field2] }
      let(:ae_field1) { MiqAeField.new(:priority => 100) }
      let(:ae_field2) { MiqAeField.new(:priority => 1) }

      before do
        allow(ae_field1).to receive(:to_export_xml) { |options| options[:builder].ae_field1 }
        allow(ae_field2).to receive(:to_export_xml) { |options| options[:builder].ae_field2 }
      end

      it "produces the expected xml" do
        expected_xml = <<-XML
<MiqAeClass name="" namespace=""><ae_method2/><ae_method1/><MiqAeSchema><ae_field2/><ae_field1/></MiqAeSchema><ae_instance2/><ae_instance1/></MiqAeClass>
        XML

        expect(miq_ae_class.to_export_xml).to eq(expected_xml.chomp)
      end
    end

    context "when the class does not have ae_fields" do
      let(:ae_fields) { [] }

      it "produces the expected xml" do
        expected_xml = <<-XML
<MiqAeClass name="" namespace=""><ae_method2/><ae_method1/><ae_instance2/><ae_instance1/></MiqAeClass>
        XML

        expect(miq_ae_class.to_export_xml).to eq(expected_xml.chomp)
      end
    end
  end

  it "#domain" do
    c1 = MiqAeClass.create(:namespace => "TEST/ABC", :name => "oleg")
    expect(c1.domain.name).to eql('TEST')
  end

  context "state_machine_class tests" do
    before do
      d1 = FactoryBot.create(:miq_ae_system_domain, :priority => 10)
      n1 = FactoryBot.create(:miq_ae_namespace, :name => 'ns1', :parent => d1)
      @c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    end

    it "class with only state field" do
      @c1.ae_fields.create(:name => "test_field", :substitute => false, :aetype => 'state')
      @c1.reload
      expect(@c1.state_machine?).to be_truthy
    end

    it "class with only attribute field" do
      @c1.ae_fields.create(:name => "test_field", :substitute => false, :aetype => 'attribute')
      @c1.reload
      expect(@c1.state_machine?).to be_falsey
    end

    it "update the field from attribute to state" do
      field1 = @c1.ae_fields.create(:name => "test_field", :substitute => false, :aetype => 'attribute')
      @c1.reload
      expect(@c1.state_machine?).to be_falsey
      field1.update(:aetype => 'state')
      @c1.reload
      expect(@c1.state_machine?).to be_truthy
    end

    it "remove the state field" do
      field1 = @c1.ae_fields.create(:name => "test_field1", :substitute => false, :aetype => 'state')
      @c1.reload
      expect(@c1.state_machine?).to be_truthy
      field1.destroy
      @c1.reload
      expect(@c1.state_machine?).to be_falsey
    end
  end

  context "waypoint_ids_for_state_machine" do
    it "check ids" do
      create_state_ae_model(:name => 'FRED', :ae_class => 'CLASS1', :ae_namespace  => 'A/B/C')
      create_state_ae_model(:name => 'FREDDY', :ae_class => 'CLASS2', :ae_namespace  => 'C/D/E')
      create_ae_model(:name => 'MARIO', :ae_class => 'CLASS3', :ae_namespace  => 'C/D/E')
      domain_fqnames = %w[FRED FREDDY]
      ns_fqnames = %w[FRED/A FRED/A/B FRED/A/B/C FREDDY/C FREDDY/C/D FREDDY/C/D/E]
      class_fqnames = %w(/FRED/A/B/C/CLASS1 /FREDDY/C/D/E/CLASS2)
      ids = domain_fqnames.collect { |ns| "MiqAeDomain::#{MiqAeNamespace.lookup_by_fqname(ns, false).id}" }
      ids += ns_fqnames.collect { |ns| "MiqAeNamespace::#{MiqAeNamespace.lookup_by_fqname(ns, false).id}" }
      ids += class_fqnames.collect { |cls| "MiqAeClass::#{MiqAeClass.lookup_by_fqname(cls).id}" }
      expect(MiqAeClass.waypoint_ids_for_state_machines).to match_array(ids)
    end

    it "no state machine classes" do
      create_ae_model(:name => 'MARIO', :ae_class => 'CLASS3', :ae_namespace  => 'C/D/E')
      expect(MiqAeClass.waypoint_ids_for_state_machines).to be_empty
    end
  end
end
