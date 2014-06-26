require "spec_helper"
include AutomationSpecHelper

describe MiqAeDomain do
  before do
    setup_model
  end

  def setup_model
    yaml_file = File.join(File.dirname(__FILE__), 'data', 'domain_test.yaml')
    import_options = {'yaml_file' => yaml_file, 'preview' => false, 'domain' => '*'}
    MiqAeImport.new('*', import_options).import
    update_domain_attributes('root', :priority => 10, :system => true, :enabled => true)
    update_domain_attributes('user', :priority => 20, :enabled => true)
    update_domain_attributes('inert', :priority => 10, :system => true, :enabled => false)
    update_domain_attributes('evm1', :priority => 100, :enabled => true)
    update_domain_attributes('evm2', :priority => 100, :enabled => true)
    @enabled_domains = %w(evm2 evm1 user root)
    @all_domains = %w(evm2 evm1 inert user root)
  end

  def update_domain_attributes(domain_name, attrs)
    dom = MiqAeDomain.find_by_fqname(domain_name)
    dom.update_attributes!(attrs)
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
    it "partial namespace should use the higher priority user instance" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      ns.should be_nil
      assert_method_executed('evm/AUTOMATE/test1', 'user')
    end

    it "fully qualified namespace should execute the root method" do
      ns = MiqAeNamespace.find_by_fqname('root/evm')
      ns.should_not be_nil
      assert_method_executed('root/evm/AUTOMATE/test2', 'root')
    end

    it "partial namespace with wild card in relationship" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      ns.should be_nil
      assert_method_executed('evm/AUTOMATE/test_wildcard', 'user')
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
      assert_method_executed('evm/AUTOMATE/should_get_used', 'inert')
    end

    it "partial namespace should use the higher priority users case insensitive instance" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      ns.should be_nil
      assert_method_executed('evm/AUTOMATE/TeSt1', 'user')
    end

    it "an enabled namespace should pick up .missing if the instance is missing" do
      update_domain_attributes('evm2', :priority => 10)
      update_domain_attributes('evm1', :priority => 40)
      assert_method_executed('test/AUTOMATE/does_not_exist', 'evm1_missing_method')
    end

    it "check list of enabled domains" do
      MiqAeDomain.enabled.collect(&:name).should match_array(@enabled_domains)
    end

    it "check list of all domains" do
      MiqAeDomain.all.collect(&:name).should match_array(@all_domains)
    end
  end
end
