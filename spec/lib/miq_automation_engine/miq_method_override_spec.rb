describe MiqAeDomain do
  include Spec::Support::AutomationHelper

  before do
    @user = FactoryGirl.create(:user_with_group)
    EvmSpecHelper.local_guid_miq_server_zone
    yaml_file = File.join(File.dirname(__FILE__), 'data', 'method_override.yaml')
    import_options = {'yaml_file' => yaml_file, 'preview' => false,
                      'domain'    => '*',       'tenant'  => Tenant.root_tenant}
    MiqAeImport.new('*', import_options).import
  end

  context 'Method Override' do
    it 'with only one domain pick the miq method' do
      set_enabled('RHT', false)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test1', 'miq', @user)
    end

    it 'pick the higher priority method in rht domain' do
      set_enabled('RHT', true)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test1', 'TwinkleToes', @user)
    end

    it 'method missing pick the method from lower priority domain' do
      set_enabled('RHT', true)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test2', 'Flintstone', @user)
    end

    def set_enabled(domain, state)
      dom = MiqAeDomain.find_by_fqname(domain)
      dom.update_attributes!(:enabled => state)
    end
  end
end
