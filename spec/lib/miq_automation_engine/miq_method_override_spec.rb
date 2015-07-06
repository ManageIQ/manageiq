require "spec_helper"
include AutomationSpecHelper

describe MiqAeDomain do
  before do
    yaml_file = File.join(File.dirname(__FILE__), 'data', 'method_override.yaml')
    import_options = {'yaml_file' => yaml_file, 'preview' => false, 'domain' => '*'}
    MiqAeImport.new('*', import_options).import
  end

  context 'Method Override' do
    it 'with only one domain pick the miq method' do
      set_enabled('RHT', false)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test1', 'miq')
    end

    it 'pick the higher priority method in rht domain' do
      set_enabled('RHT', true)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test1', 'TwinkleToes')
    end

    it 'method missing pick the method from lower priority domain' do
      set_enabled('RHT', true)
      set_enabled('MIQ', true)
      assert_method_executed('evm/SAMPLE/test2', 'Flintstone')
    end

    def set_enabled(domain, state)
      dom = MiqAeDomain.find_by_fqname(domain)
      dom.update_attributes!(:enabled => state)
    end
  end
end
