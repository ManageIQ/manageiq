require "spec_helper"

module MiqAeServiceHostSpec
  describe MiqAeMethodService::MiqAeServiceHost do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'
      @host = FactoryGirl.create(:host)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Host::host=#{@host.id}")
    end

    context "$evm.vmdb" do
      it "with no parms" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host')"
        @ae_method.update_attributes(:data => method)
        ae_result = invoke_ae.root(@ae_result_key)
        ae_result.should == MiqAeMethodService::MiqAeServiceHost

        ae_result.count.should == 1

        hosts = ae_result.all
        hosts[0].should be_kind_of(MiqAeMethodService::MiqAeServiceHost)
        hosts[0].id.should == @host.id

        method   = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host').count"
        @ae_method.update_attributes(:data => method)
        ae_result = invoke_ae.root(@ae_result_key)
        ae_result.should == 1
      end

      it "with id" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host', #{@host.id})"
        @ae_method.update_attributes(:data => method)
        ae_result = invoke_ae.root(@ae_result_key)
        ae_result.should be_kind_of(MiqAeMethodService::MiqAeServiceHost)
        ae_result.id.should == @host.id
      end

      it "with array of ids" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host', [#{@host.id}])"
        @ae_method.update_attributes(:data => method)
        ae_result = invoke_ae.root(@ae_result_key)
        ae_result.should be_kind_of(Array)

        hosts = ae_result
        hosts.length.should == 1
        hosts[0].should be_kind_of(MiqAeMethodService::MiqAeServiceHost)
        hosts[0].id.should == @host.id
      end

    end

    it "#ems_custom_keys" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['host'].ems_custom_keys"
      @ae_method.update_attributes(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should be_kind_of(Array)
      ae_result.should be_empty

      key1   = 'key1'
      value1 = 'value1'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @host, :name => key1, :value => value1)
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should be_kind_of(Array)
      ae_result.length.should == 1
      ae_result.first.should == key1

      key2   = 'key2'
      value2 = 'value2'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @host, :name => key2, :value => value2)
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should be_kind_of(Array)
      ae_result.length.should == 2
      ae_result.sort.should == [key1, key2]
    end

    it "#ems_custom_get" do
      key    = 'key1'
      value  = 'value1'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['host'].ems_custom_get('#{key}')"
      @ae_method.update_attributes(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should be_nil

      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @host, :name => key, :value => value)
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should == value
    end

    it "#get_realtime_metric" do
      metric   = 'metric1'
      range    = 10.minutes
      function = :max
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['host'].get_realtime_metric('#{metric}', #{range}, :#{function})"
      @ae_method.update_attributes(:data => method)
      Host.any_instance.should_receive(:get_performance_metric).with(:realtime, metric, range, function).once
      ae_result = invoke_ae.root(@ae_result_key)
      ae_result.should be_nil
    end
  end
end
