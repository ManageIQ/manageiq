require "spec_helper"

module MiqAeServiceServiceReconfigureTaskSpec
  describe MiqAeMethodService::MiqAeServiceServiceReconfigureTask do
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

      MiqAeDatastore::Import.load_xml(xml)
      FactoryGirl.create(:ui_task_set_approver)
    end

    let(:ae_method) { ::MiqAeMethod.find(:first) }
    let(:user)      { FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred') }
    let(:options)   { {} }
    let(:task)      do
      FactoryGirl.create(:service_reconfigure_task,
                         :state        => 'pending',
                         :status       => 'Ok',
                         :request_type => 'service_reconfigure',
                         :options      => options)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceReconfigureTask::service_reconfigure_task=#{task.id}")
    end

    context "#status" do
      it "returns 'ok' when state is finished" do
        task.update_attributes(:state => "finished")
        method   = "$evm.root['result'] = $evm.root['service_reconfigure_task'].status"
        ae_method.update_attributes!(:data => method)

        invoke_ae.root('result').should == 'ok'
      end

      it "returns 'retry' when state is pending" do
        task.update_attributes(:state => "pending")
        method   = "$evm.root['result'] = $evm.root['service_reconfigure_task'].status"
        ae_method.update_attributes!(:data => method)

        invoke_ae.root('result').should == 'retry'
      end
    end
  end
end
