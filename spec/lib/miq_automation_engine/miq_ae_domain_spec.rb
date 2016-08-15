describe MiqAeDomain do
  include Spec::Support::AutomationHelper

  let(:root_tenant) { Tenant.seed }
  before do
    @user = FactoryGirl.create(:user_with_group)
    EvmSpecHelper.local_miq_server
    root_tenant
    setup_model
  end

  def setup_model
    yaml_file = File.join(File.dirname(__FILE__), 'data', 'domain_test.yaml')
    import_options = {'yaml_file' => yaml_file, 'preview' => false, 'domain' => '*', 'tenant_id' => root_tenant.id}
    MiqAeImport.new('*', import_options).import
    update_domain_attributes('root', :priority => 10, :enabled => true)
    update_domain_attributes('user', :priority => 20, :enabled => true)
    update_domain_attributes('inert', :priority => 10, :enabled => false)
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
      domain = MiqAeDomain.create!(:name => 'Fred', :tenant => root_tenant)
      ns = MiqAeNamespace.create!(:name => 'NS1')
      expect { domain.update_attributes!(:parent_id => ns.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can set other attributes in a domain object' do
      domain = MiqAeDomain.create!(:name => 'Fred', :tenant => root_tenant)
      expect(domain.update_attributes!(:priority => 10)).to be_truthy
    end
  end

  context "Domain Overlays" do
    it "partial namespace should use the higher priority user instance" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      expect(ns).to be_nil
      assert_method_executed('evm/AUTOMATE/test1', 'user', @user)
    end

    it "fully qualified namespace should execute the root method" do
      ns = MiqAeNamespace.find_by_fqname('root/evm')
      expect(ns).not_to be_nil
      assert_method_executed('root/evm/AUTOMATE/test2', 'root', @user)
    end

    it "partial namespace with wild card in relationship" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      expect(ns).to be_nil
      assert_method_executed('evm/AUTOMATE/test_wildcard', 'user', @user)
    end

    it "a non existent partial namespace instance should fail" do
      ws = MiqAeEngine.instantiate('evm/AUTOMATE/non_existent', @user)
      roots = ws.roots
      expect(roots.size).to eq(0)
    end

    it "a disabled namespace should not get picked up even if the instance exists" do
      ws = MiqAeEngine.instantiate('evm/AUTOMATE/should_not_get_used', @user)
      roots = ws.roots
      expect(roots.size).to eq(0)
    end

    it "an enabled namespace should get picked up if the instance exists" do
      n3 = MiqAeNamespace.find_by_fqname('inert')
      expect(n3.enabled?).to be_falsey
      n3.update_attributes!(:enabled => true)
      assert_method_executed('evm/AUTOMATE/should_get_used', 'inert', @user)
    end

    it "partial namespace should use the higher priority users case insensitive instance" do
      ns = MiqAeNamespace.find_by_fqname('evm')
      expect(ns).to be_nil
      assert_method_executed('evm/AUTOMATE/TeSt1', 'user', @user)
    end

    it "an enabled namespace should pick up .missing if the instance is missing" do
      update_domain_attributes('evm2', :priority => 10)
      update_domain_attributes('evm1', :priority => 40)
      assert_method_executed('test/AUTOMATE/does_not_exist', 'evm1_missing_method', @user)
    end

    it "check list of enabled domains" do
      expect(MiqAeDomain.enabled.collect(&:name)).to match_array(@enabled_domains)
    end

    it "check list of all domains" do
      expect(MiqAeDomain.all.collect(&:name)).to match_array(@all_domains)
    end
  end
end
