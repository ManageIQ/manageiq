require "spec_helper"

module MiqAeServiceMiqRequestSpec
  describe MiqAeMethodService::MiqAeServiceMiqRequest do
    def assert_ae_user_matches_ar_user(ae_user, ar_user)
      ae_user.should be_kind_of(MiqAeMethodService::MiqAeServiceUser)
      [:id, :name, :userid, :email].each { |method| ae_user.send(method).should == ar_user.send(method) }
    end

    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver_role = FactoryGirl.create(:ui_task_set_approver)
      @miq_request   = FactoryGirl.create(:miq_request, :requester => @fred)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqRequest::miq_request=#{@miq_request.id}")
    end

    it "#approve" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].approve('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      MiqRequest.any_instance.should_receive(:approve).with(approver, reason).once
      invoke_ae.root(@ae_result_key).should  be_true
    end

    it "#deny" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].deny('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      MiqRequest.any_instance.should_receive(:deny).with(approver, reason).once
      invoke_ae.root(@ae_result_key).should  be_true
    end

    it "#pending" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].pending"
      @ae_method.update_attributes(:data => method)
      MiqRequest.any_instance.should_receive(:pending).once
      invoke_ae.root(@ae_result_key).should  be_true
    end

    it "#approvers" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].approvers"
      @ae_method.update_attributes(:data => method)
      invoke_ae.root(@ae_result_key).should == []

      wilma          = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'wilma',  :email => 'wilma@bedrock.gov')
      betty          = FactoryGirl.create(:user, :name => 'Betty Rubble',     :userid => 'betty',  :email => 'betty@bedrock.gov')
      wilma_approval = FactoryGirl.create(:miq_approval, :approver => wilma)
      betty_approval = FactoryGirl.create(:miq_approval, :approver => betty)
      @miq_request.miq_approvals = [wilma_approval, betty_approval]
      @miq_request.save!

      approvers = invoke_ae.root(@ae_result_key)
      approvers.should be_kind_of(Array)
      approvers.length.should == 2

      approvers.each do |ae_user|
        ae_user.should be_kind_of(MiqAeMethodService::MiqAeServiceUser)
        [wilma.id, betty.id].should include(ae_user.id)
        ar_user =
          case ae_user.id
          when wilma.id then wilma
          when betty.id then betty
          end
        assert_ae_user_matches_ar_user(ae_user, ar_user)
      end
    end

    it "#requester" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].requester"
      @ae_method.update_attributes(:data => method)
      fred = invoke_ae.root(@ae_result_key)
      assert_ae_user_matches_ar_user(fred, @fred)
    end

    it "#authorized?" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].authorized?"
      @ae_method.update_attributes(:data => method)
      [true, false].each do |expected_authorized|
        MiqRequest.any_instance.stub(:authorized?).and_return(expected_authorized)
        authorized = invoke_ae.root(@ae_result_key)
        authorized.should == expected_authorized
      end
    end

    it "#resource" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].resource"
      @ae_method.update_attributes(:data => method)

      vm_template = FactoryGirl.create(:template_vmware, :name => "template1")
      resource    = FactoryGirl.create(:miq_provision_request, :userid => @fred.userid, :src_vm_id => vm_template.id)
      resource.create_request
      @miq_request = resource
      @miq_request.save!

      ae_resource = invoke_ae.root(@ae_result_key)
      ae_class    = "MiqAeMethodService::MiqAeService#{resource.class.name}".constantize
      ae_resource.should be_kind_of(ae_class)
      [:userid, :src_vm_id].each { |method| ae_resource.send(method).should == resource.send(method) }
    end

    it "#reason" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].reason"
      @ae_method.update_attributes(:data => method)
      reason = invoke_ae.root(@ae_result_key)
      reason.should == ""

      wilma          = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'wilma',  :email => 'wilma@bedrock.gov')
      betty          = FactoryGirl.create(:user, :name => 'Betty Rubble',     :userid => 'betty',  :email => 'betty@bedrock.gov')
      wilma_approval = FactoryGirl.create(:miq_approval, :approver => wilma)
      betty_approval = FactoryGirl.create(:miq_approval, :approver => betty)
      @miq_request.miq_approvals = [wilma_approval, betty_approval]
      @miq_request.save!

      MiqApproval.any_instance.stub(:authorized?).and_return(true)
      MiqRequest.any_instance.stub(:approval_denied)

      betty_reason = "Where's Barney?"
      betty_approval.deny(betty.userid, betty_reason)
      #betty_approval.update_attributes(:state => 'denied', :reason => betty_reason)
      reason = invoke_ae.root(@ae_result_key)
      reason.should == betty_reason

      wilma_reason = "Where's Fred?"
      wilma_approval.deny(wilma.userid, wilma_reason)
      #wilma_approval.update_attributes(:state => 'denied', :reason => wilma_reason)
      reasons = invoke_ae.root(@ae_result_key)
      # Order of reasons is indeterminate
      reasons.split('; ').each { |reason| [betty_reason, wilma_reason].include?(reason).should be_true }
    end

    it "#options" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].options"
      @ae_method.update_attributes(:data => method)
      options = { :a => 1, :b => 'two' }
      @miq_request.update_attributes(:options => options)
      invoke_ae.root(@ae_result_key).should == options
    end

    it "#get_option" do
      key    = 'key1'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_option('#{key}')"
      @ae_method.update_attributes(:data => method)

      [ ['three hundred', 'three hundred'], [ ['one', 'two'], 'one'] ].each do |value, expected|
        options = { :a => 1, :b => 'two', key => value }
        @miq_request.update_attributes(:options => options)
        invoke_ae.root(@ae_result_key).should == expected
      end
    end

    it "#set_option" do
      options = { :a => 1, :b => 'two' }
      @miq_request.update_attributes(:options => options)
      key     = 'foo'
      value   = 'bar'
      method  = "$evm.root['miq_request'].set_option('#{key}', '#{value}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      new_options      = options.dup
      new_options[key] = value
      @miq_request.reload.options.should == new_options
    end

    it "#get_tag" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_tag('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequest.any_instance.should_receive(:get_tag).with(category).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#get_tags" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_tags"
      @ae_method.update_attributes(:data => method)
      tags = ['tag1', 'tag2']
      MiqRequest.any_instance.should_receive(:get_tags).once.and_return(tags)
      invoke_ae.root(@ae_result_key).should == tags
    end

    context "#clear_tag" do
      it "should work with no parms" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag"
        @ae_method.update_attributes(:data => method)
        MiqRequest.any_instance.should_receive(:clear_tag).with(nil, nil).once
        invoke_ae
      end

      it "should work with 1 parm" do
        category = 'category1'
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag('#{category}')"
        @ae_method.update_attributes(:data => method)
        MiqRequest.any_instance.should_receive(:clear_tag).with(category, nil).once
        invoke_ae
      end

      it "should work with 2 parms" do
        category = 'category1'
        tag_name = 'tag_name1'
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag('#{category}', '#{tag_name}')"
        @ae_method.update_attributes(:data => method)
        MiqRequest.any_instance.should_receive(:clear_tag).with(category, tag_name).once
        invoke_ae
      end
    end

    it "#get_classification" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_classification('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequest.any_instance.should_receive(:get_classification).with(category).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#get_classifications" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_classifications"
      @ae_method.update_attributes(:data => method)
      classifications = ['classification1', 'classification2']
      MiqRequest.any_instance.should_receive(:get_classifications).once.and_return(classifications)
      invoke_ae.root(@ae_result_key).should == classifications
    end

    it "#set_message" do
      message = 'message1'
      method  = "$evm.root['miq_request'].set_message('#{message}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      @miq_request.reload.message.should == message
    end
  end
end
