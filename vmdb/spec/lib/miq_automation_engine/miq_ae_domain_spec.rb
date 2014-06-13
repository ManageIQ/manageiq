require "spec_helper"

module MiqAeDomainSpec
  include MiqAeEngine
  describe "MiqAeDomain" do
    before(:each) do
      MiqServer.my_server_clear_cache
      MiqAeDatastore.reset
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    context 'Domain Checks' do
      it 'cannot set parent_id in a domain object' do
        domain = MiqAeDomain.create!(:name => 'Fred')
        ns = MiqAeNamespace.create!(:name => 'NS1')
        expect { domain.update_attributes!(:parent_id => ns.id) }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'can set other attributes in a domain object' do
        domain = MiqAeDomain.create!(:name => 'Fred')
        domain.update_attributes!(:priority => 10, :system => false).should be_true
      end

    end

    context "Domain Overlays" do
      before(:each) do
        base_dir = File.join(File.dirname(__FILE__), "data")
        attrs = {:priority => 10, :system => true}
        EvmSpecHelper.import_yaml_model(File.join(base_dir, "root_domain"), "root", attrs)
        attrs = {:priority => 20}
        EvmSpecHelper.import_yaml_model(File.join(base_dir, "user_domain"), "user", attrs)

        attrs = {:priority => 10, :system => true, :enabled => false}
        EvmSpecHelper.import_yaml_model(File.join(base_dir, "inert_domain"), "inert", attrs)
        attrs = {:priority => 100}
        EvmSpecHelper.import_yaml_model(File.join(base_dir, "evm1_domain"), "evm1", attrs)
        attrs = {:priority => 100}
        EvmSpecHelper.import_yaml_model(File.join(base_dir, "evm2_domain"), "evm2", attrs)
        @enabled_domains = %w(evm2 evm1 user root)
        @all_domains = %w(evm2 evm1 inert user root)
      end

      it "partial namespace should use the higher priority user instance" do
        ns = MiqAeNamespace.find_by_fqname('evm')
        ns.should be_nil
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/test1')
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'user'
      end

      it "fully qualified namespace should execute the root method" do
        ns = MiqAeNamespace.find_by_fqname('root/evm')
        ns.should_not be_nil
        ws = MiqAeEngine.instantiate("root/evm/AUTOMATE/test2")
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'root'
      end

      it "partial namespace with wild card in relationship" do
        ns = MiqAeNamespace.find_by_fqname('evm')
        ns.should be_nil
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/test_wildcard')
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'user'
      end

      it "a non existent partial namespace instance should fail" do
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/non_existent')
        roots = ws.roots
        roots.should have(0).item
      end

      it "a disabled namespace should not get picked up even if the instance exists" do
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/should_not_get_used')
        roots = ws.roots
        roots.should have(0).item
      end

      it "an enabled namespace should get picked up if the instance exists" do
        n3 = MiqAeNamespace.find_by_fqname('inert')
        n3.enabled?.should be_false
        n3.update_attributes!(:enabled => true)
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/should_get_used')
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'inert'
      end

      it "partial namespace should use the higher priority users case insensitive instance" do
        ns = MiqAeNamespace.find_by_fqname('evm')
        ns.should be_nil
        ws = MiqAeEngine.instantiate('evm/AUTOMATE/TeSt1')
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'user'
      end

      it "an enabled namespace should pick up .missing if the instance is missing" do
        n3 = MiqAeNamespace.find_by_fqname('evm2')
        n3.update_attributes!(:priority => 10)
        n3 = MiqAeNamespace.find_by_fqname('evm1')
        n3.update_attributes!(:priority => 40)
        ws = MiqAeEngine.instantiate('test/AUTOMATE/does_not_exist')
        ws.should_not be_nil
        roots = ws.roots
        roots.should have(1).item
        roots.first.attributes['method_executed'].should == 'evm1_missing_method'
      end

      it "check list of enabled domains" do
        MiqAeDomain.enabled.collect(&:name).should match_array(@enabled_domains)
      end

      it "check list of all domains" do
        MiqAeDomain.all.collect(&:name).should match_array(@all_domains)
      end
    end
  end
end
