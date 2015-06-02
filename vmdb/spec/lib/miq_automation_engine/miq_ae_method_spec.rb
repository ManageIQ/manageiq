require "spec_helper"

module MiqAeMethodSpec
  include MiqAeEngine
  describe MiqAeMethod do
    before(:each) do
      MiqAeDatastore.reset
      @domain = 'SPEC_DOMAIN'
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
    end

    def setup_methods
      object_class = MiqAeClass.find_by_fqname("#{MiqAeDatastore::DEFAULT_OBJECT_NAMESPACE}/Object")
      method_data = '$evm.log("info", "Default Class Method")
        exit MIQ_OK'
      method_options = {:language => 'ruby', :class_id => object_class.id,
                        :data => method_data, :location => 'inline'}
      params = [{:name => 'num1', :priority => 1, :datatype => 'integer'},
                {:name => 'num2', :priority => 2, :datatype => 'integer', :default_value => 0}]
      foo_c = FactoryGirl.create(:miq_ae_method, method_options.merge(:name => 'foo', :scope => 'class'))
      foo_c.inputs.build(params)
      foo_c.save!
      foo_i = FactoryGirl.create(:miq_ae_method, method_options.merge(:name => 'foo', :scope => 'instance'))
      foo_i.inputs.build(params)
      foo_i.save!
      method_options = {:language => 'ruby', :name => 'non_existent',
                        :scope => 'instance', :location => 'builtin',
                        :class_id => object_class.id}
      FactoryGirl.create(:miq_ae_method, method_options)
    end

    it "integrates with base methods of MiqAeServiceModelBase" do
      vm_name = 'fred flintstone'
      vm = FactoryGirl.create(:vm_vmware, :name => vm_name)
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_method_spec1"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Vm::vm=#{vm.id}")
      ws.root("vm_id_via_hash").should     == vm.id
      ws.root("vm_id_via_call").should     == vm.id
      ws.root("vm_name").should            == vm.name
      ws.root("vm_normalized_name").should == vm.name.tr(' ', '_')
    end

    it "decrypts passwords upon request" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_method_spec2"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1")
      ws.root("decrypted").should == 'secret'
      ws.root("encrypted").should == '********'
    end

    it "properly processes instance methods via no inheritance" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "method2"), @domain)
      MiqAeDatastore.reset_default_namespace
      setup_methods
      ws = MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_default")
      ws.should_not be_nil
      ws = MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_inline")
      ws.should_not be_nil
      # puts ws.to_expanded_xml()
    end

    it "properly processes instance methods via relationship via no inheritance" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "method2"), @domain)
      MiqAeDatastore.reset_default_namespace
      setup_methods
      -> { MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_missing_parameter") }.should \
        raise_error(MiqAeException::MethodParmMissing)
      -> { MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_non_existent_internal") }.should \
        raise_error(MiqAeException::MethodNotFound)
      -> { MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_missing") }.should \
        raise_error(MiqAeException::MethodNotFound)
      MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_internal").should_not be_nil
      MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_inline").should_not be_nil
    end

    it "is case-insensitive for method invocation" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "method2"), @domain)
      MiqAeDatastore.reset_default_namespace
      setup_methods
      MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/FOO/test_builtin_with_different_case").should_not be_nil
    end

    it "can access *current* set of attributes from within method" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_method_spec4"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1")
      ws.root("current_namespace").should eql("#{@domain}/EVM")
      ws.root("current_class").should eql('AUTOMATE')
      ws.root("current_instance").should eql('test1')
      ws.root("current_message").should eql('create')
      ws.root("current_method").should eql('test')
    end

    it "handles datatype conversion" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_method_spec5"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?flag=false&flag2=true&int=5&float=5.87&symbol=test&array=1,2,3")

      expect(ws.root("flag")).to   be_false
      expect(ws.root("flag2")).to  be_true
      expect(ws.root("int")).to    eq(5)
      expect(ws.root("float")).to  eq(5.87)
      expect(ws.root("symbol")).to eq(:test)
      expect(ws.root("array")).to  match_array(%w(1 2 3))
    end

    it "properly processes console web services" do
      # These tests are meant to be run manually (for now) via script/console.
      # They require that the EVM Server be up and running to provide web services
      # and that the EVM Server and these tests use the same database.

      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "method3"), @domain)
      MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/WSTEST/test_inline").should_not be_nil
      # MiqAeEngine.instantiate("/EVM/SYSTEM/TEST/WSTEST/test_perl_intra_method_get_set_get").should_not be_nil

      # Contents of Perl Script
      # #!perl -w
      #
      # use SOAP::Lite;
      #
      # my $miq_token = $ENV{'MIQ_TOKEN'};
      # print "\nMIQ_TOKEN => ", $miq_token;
      #
      # my $service = SOAP::Lite
      #     -> service('http://localhost:3000/vmdbws/wsdl');
      #
      # # print "\nEVMPing =>", $service->EVMPing("Hello World");
      # print "\nEVMGet =>", $service->EVMGet($miq_token, "#tester");
      # print "\nEVMSet =>", $service->EVMSet($miq_token, "#tester", "Oleg Barenboim");
      # print "\nEVMGet =>", $service->EVMGet($miq_token, "#tester");
      #
      # exit 0;

    end

  end
end
