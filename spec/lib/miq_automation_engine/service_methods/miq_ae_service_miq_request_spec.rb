module MiqAeServiceMiqRequestSpec
  describe MiqAeMethodService::MiqAeServiceMiqRequest do
    def assert_ae_user_matches_ar_user(ae_user, ar_user)
      expect(ae_user).to be_kind_of(MiqAeMethodService::MiqAeServiceUser)
      [:id, :name, :userid, :email].each { |method| expect(ae_user.send(method)).to eq(ar_user.send(method)) }
    end

    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @fred          = FactoryGirl.create(:user_with_group)
      @miq_request   = FactoryGirl.create(:automation_request, :requester => @fred)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqRequest::miq_request=#{@miq_request.id}", @fred)
    end

    it "#approve" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].approve('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      expect(MiqRequest).to receive(:find).with(@miq_request.id.to_s).and_return(@miq_request)
      expect(@miq_request).to receive(:approve).with(approver, reason).once
      expect(invoke_ae.root(@ae_result_key)).to  be_truthy
    end

    it "#deny" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].deny('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      expect(MiqRequest).to receive(:find).with(@miq_request.id.to_s).and_return(@miq_request)
      expect(@miq_request).to receive(:deny).with(approver, reason).once
      expect(invoke_ae.root(@ae_result_key)).to  be_truthy
    end

    it "#pending" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].pending"
      @ae_method.update_attributes(:data => method)
      expect_any_instance_of(MiqRequest).to receive(:pending).once
      expect(invoke_ae.root(@ae_result_key)).to  be_truthy
    end

    it "#approvers" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].approvers"
      @ae_method.update_attributes(:data => method)
      expect(invoke_ae.root(@ae_result_key)).to eq([])

      wilma          = FactoryGirl.create(:user_with_email_and_group)
      betty          = FactoryGirl.create(:user_with_email_and_group)
      wilma_approval = FactoryGirl.create(:miq_approval, :approver => wilma)
      betty_approval = FactoryGirl.create(:miq_approval, :approver => betty)
      @miq_request.miq_approvals = [wilma_approval, betty_approval]
      @miq_request.save!

      approvers = invoke_ae.root(@ae_result_key)
      expect(approvers).to be_kind_of(Array)
      expect(approvers.length).to eq(2)

      approvers.each do |ae_user|
        expect(ae_user).to be_kind_of(MiqAeMethodService::MiqAeServiceUser)
        expect([wilma.id, betty.id]).to include(ae_user.id)
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
        allow_any_instance_of(MiqRequest).to receive(:authorized?).and_return(expected_authorized)
        authorized = invoke_ae.root(@ae_result_key)
        expect(authorized).to eq(expected_authorized)
      end
    end

    it "#resource" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].resource"
      @ae_method.update_attributes(:data => method)

      vm_template = FactoryGirl.create(:template_vmware, :name => "template1")
      resource    = FactoryGirl.create(:miq_provision_request, :requester => @fred, :src_vm_id => vm_template.id)
      @miq_request = resource

      ae_resource = invoke_ae.root(@ae_result_key)
      ae_class    = "MiqAeMethodService::MiqAeService#{resource.class.name.gsub(/::/, '_')}".constantize
      expect(ae_resource).to be_kind_of(ae_class)
      [:userid, :src_vm_id].each { |method| expect(ae_resource.send(method)).to eq(resource.send(method)) }
    end

    it "#reason" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].reason"
      @ae_method.update_attributes(:data => method)
      reason = invoke_ae.root(@ae_result_key)
      expect(reason).to be_nil

      betty          = FactoryGirl.create(:user_with_email_and_group)
      betty_approval = FactoryGirl.create(:miq_approval, :approver => betty)
      @miq_request.miq_approvals = [betty_approval]
      @miq_request.save!

      allow_any_instance_of(MiqApproval).to receive(:authorized?).and_return(true)
      allow_any_instance_of(MiqRequest).to receive(:approval_denied)

      betty_reason = "Where's Barney?"
      betty_approval.deny(betty.userid, betty_reason)
      # betty_approval.update_attributes(:state => 'denied', :reason => betty_reason)
      reason = invoke_ae.root(@ae_result_key)
      expect(reason).to eq(betty_reason)

      wilma          = FactoryGirl.create(:user_with_email_and_group)
      wilma_approval = FactoryGirl.create(:miq_approval, :approver => wilma)
      @miq_request.miq_approvals << wilma_approval
      wilma_reason = "Where's Fred?"
      wilma_approval.deny(wilma.userid, wilma_reason)
      # wilma_approval.update_attributes(:state => 'denied', :reason => wilma_reason)
      reasons = invoke_ae.root(@ae_result_key)
      # Order of reasons is indeterminate
      reasons.split('; ').each { |reason| expect([betty_reason, wilma_reason].include?(reason)).to be_truthy }
    end

    it "#options" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].options"
      @ae_method.update_attributes(:data => method)
      options = {:a => 1, :b => 'two'}
      @miq_request.update_attributes(:options => options)
      expect(invoke_ae.root(@ae_result_key)).to eq(options)
    end

    it "#get_option" do
      key    = 'key1'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_option('#{key}')"
      @ae_method.update_attributes(:data => method)

      [['three hundred', 'three hundred'], [['one', 'two'], 'one']].each do |value, expected|
        options = {:a => 1, :b => 'two', key => value}
        @miq_request.update_attributes(:options => options)
        expect(invoke_ae.root(@ae_result_key)).to eq(expected)
      end
    end

    it "#set_option" do
      options = {:a => 1, :b => 'two'}
      @miq_request.update_attributes(:options => options)
      key     = 'foo'
      value   = 'bar'
      method  = "$evm.root['miq_request'].set_option('#{key}', '#{value}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      new_options      = options.dup
      new_options[key] = value
      expect(@miq_request.reload.options).to eq(new_options)
    end

    it "#get_tag" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_tag('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequest).to receive(:get_tag).with(category).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#get_tags" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_tags"
      @ae_method.update_attributes(:data => method)
      tags = ['tag1', 'tag2']
      expect_any_instance_of(MiqRequest).to receive(:get_tags).once.and_return(tags)
      expect(invoke_ae.root(@ae_result_key)).to eq(tags)
    end

    context "#clear_tag" do
      it "should work with no parms" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag"
        @ae_method.update_attributes(:data => method)
        expect_any_instance_of(MiqRequest).to receive(:clear_tag).with(nil, nil).once
        invoke_ae
      end

      it "should work with 1 parm" do
        category = 'category1'
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag('#{category}')"
        @ae_method.update_attributes(:data => method)
        expect_any_instance_of(MiqRequest).to receive(:clear_tag).with(category, nil).once
        invoke_ae
      end

      it "should work with 2 parms" do
        category = 'category1'
        tag_name = 'tag_name1'
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].clear_tag('#{category}', '#{tag_name}')"
        @ae_method.update_attributes(:data => method)
        expect_any_instance_of(MiqRequest).to receive(:clear_tag).with(category, tag_name).once
        invoke_ae
      end
    end

    it "#get_classification" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_classification('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequest).to receive(:get_classification).with(category).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#get_classifications" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request'].get_classifications"
      @ae_method.update_attributes(:data => method)
      classifications = ['classification1', 'classification2']
      expect_any_instance_of(MiqRequest).to receive(:get_classifications).once.and_return(classifications)
      expect(invoke_ae.root(@ae_result_key)).to eq(classifications)
    end

    it "#set_message" do
      message = 'message1'
      method  = "$evm.root['miq_request'].set_message('#{message}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      expect(@miq_request.reload.message).to eq(message)
    end

    it "#description=" do
      description = 'test description'
      method  = "$evm.root['miq_request'].description=('#{description}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      expect(@miq_request.reload.description).to eq(description)
    end
  end
end
