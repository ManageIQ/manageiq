require "spec_helper"

module MiqAeServiceServiceReconfigureRequestSpec
  describe MiqAeMethodService::MiqAeServiceServiceReconfigureRequest do
    before(:each) do
      xml = <<-XML
      <MiqAeDatastore version='1.0'>
        <MiqAeClass name="AUTOMATE" namespace="EVM">
          <MiqAeSchema>
            <MiqAeField name="method1"  aetype="method"/>
          </MiqAeSchema>
          <MiqAeMethod name="test" language="ruby" location="inline" scope="instance">
          <![CDATA[
          ]]>
          </MiqAeMethod>
          <MiqAeInstance name="test1">
            <MiqAeField name="method1">test</MiqAeField>
          </MiqAeInstance>
        </MiqAeClass>
      </MiqAeDatastore>
      XML

      # hide deprecation warning
      expect(MiqAeDatastore).to receive(:xml_deprecated_warning)
      MiqAeDatastore::Import.load_xml(xml)
      FactoryGirl.create(:ui_task_set_approver)
    end

    let(:ae_method)     { ::MiqAeMethod.find(:first) }
    let(:user)          { FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred') }
    let(:request)       { FactoryGirl.create(:service_reconfigure_request, :requester => user, :userid => user.userid) }

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceReconfigureRequest::request=#{request.id}")
    end

    it "returns 'service' for ci_type" do
      method   = "$evm.root['ci_type'] = $evm.root['request'].ci_type"
      ae_method.update_attributes(:data => method)
      invoke_ae.root('ci_type').should == 'service'
    end
  end
end
