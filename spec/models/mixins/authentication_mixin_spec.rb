describe AuthenticationMixin do
  before(:each) do
    class TestClass < ActiveRecord::Base
      self.table_name = "vms"
      include AuthenticationMixin
    end
  end

  after(:each) do
    Object.send(:remove_const, :TestClass)
  end

  shared_examples "authentication_components" do |method, required_field|
    context "##{method}" do
      let(:expected) do
        case method
        when :has_credentials?
          false
        when :missing_credentials?
          true
        end
      end

      it "no authentication" do
        t = TestClass.new
        allow(t).to receive_messages(:authentication_best_fit => nil)
        expect(t.send(method)).to eq(expected)
      end

      it "no #{required_field}" do
        t = TestClass.new
        allow(t).to receive_messages(:authentication_best_fit => double(required_field => nil))
        expect(t.send(method)).to eq(expected)
      end

      it "blank #{required_field}" do
        t = TestClass.new
        allow(t).to receive_messages(:authentication_best_fit => double(required_field => ""))
        expect(t.send(method)).to eq(expected)
      end

      it "normal case" do
        t = TestClass.new
        allow(t).to receive_messages(:authentication_best_fit => double(required_field => "test"))

        expected = case method
                   when :has_credentials?
                     true
                   when :missing_credentials?
                     false
                   else
                     "test"
                   end

        expect(t.send(method)).to eq(expected)
      end
    end
  end

  include_examples "authentication_components", :authentication_password, :password
  include_examples "authentication_components", :authentication_userid, :userid
  include_examples "authentication_components", :authentication_password_encrypted, :password_encrypted
  include_examples "authentication_components", :has_credentials?, :userid
  include_examples "authentication_components", :missing_credentials?, :userid

  context "required fields" do
    context "requires one field" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => {:userid => "test_user"}}
        options = {:required => :userid}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_truthy
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => {:userid => "test_user"}}
        options = {:required => :password}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end

    context "requires both fields" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => {:userid => "test_user", :password => "test_pass"}}
        options = {:required => [:userid, :password]}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_truthy
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => {:userid => "test_user"}}
        options = {:required => [:userid, :password]}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end
  end

  context "authorization event and check for container providers" do
    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
    end

    it "should be triggered for kubernetes" do
      auth = AuthToken.new(:name => "bearer", :auth_key => "valid-token")
      FactoryGirl.create(:ems_kubernetes, :authentications => [auth])

      expect(MiqQueue.count).to eq(2)
      expect(MiqQueue.find_by(:method_name => 'raise_evm_event')).not_to be_nil
      expect(MiqQueue.find_by(:method_name => 'authentication_check_types')).not_to be_nil
    end

    it "should be triggered for openshift" do
      auth = AuthToken.new(:name => "bearer", :auth_key => "valid-token")
      FactoryGirl.create(:ems_openshift, :authentications => [auth])

      expect(MiqQueue.count).to eq(2)
      expect(MiqQueue.find_by(:method_name => 'raise_evm_event')).not_to be_nil
      expect(MiqQueue.find_by(:method_name => 'authentication_check_types')).not_to be_nil
    end
  end

  context "with server and zone" do
    before(:each) do
      @miq_server = EvmSpecHelper.local_miq_server
      @data = {:default => {:userid => "test", :password => "blah"}}
    end

    context "with multiple zones, emses, and hosts" do
      before(:each) do
        @zone1 = @miq_server.zone
        @zone2 = FactoryGirl.create(:zone, :name => 'test1')
        @ems1  = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone1)
        @ems2  = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone2)
        @host1 = FactoryGirl.create(:host_with_authentication, :ext_management_system => @ems1)
        @host2 = FactoryGirl.create(:host_with_authentication, :ext_management_system => @ems2)

        # Destroy any queued auth checks from creating the new CI's with authentications
        MiqQueue.destroy_all
      end

      it "Host.authentication_check_schedule will enqueue for current zone" do
        Host.authentication_check_schedule
        expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host1.id, :zone => @host1.my_zone)).to be_truthy
        expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host2.id).count).to eq(0)
      end

      it "Ems.authentication_check_schedule will enqueue for current zone" do
        ExtManagementSystem.authentication_check_schedule
        expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :zone => @ems1.my_zone)).to be_truthy
        expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id).count).to eq(0)
      end

      it "Host.authentication_check_schedule will enqueue for role 'smartstate' for current zone" do
        Host.authentication_check_schedule
        expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host1.id, :zone => @host1.my_zone, :role => @host1.authentication_check_role)).to be_truthy
        expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host2.id).count).to eq(0)
      end

      it "Ems.authentication_check_schedule will enqueue for role 'ems_operations' for current zone" do
        ExtManagementSystem.authentication_check_schedule
        expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :role => @ems1.authentication_check_role)).to be_truthy
        expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id).count).to eq(0)
      end
    end

    context "with a host and ems" do
      before(:each) do
        @host = FactoryGirl.create(:host_vmware_esx_with_authentication)
        @ems  = FactoryGirl.create(:ems_vmware_with_authentication)
        MiqQueue.destroy_all
        @auth = @ems.authentication_type(:default)
        @orig_ems_user, @orig_ems_pwd = @ems.auth_user_pwd(:default)
      end

      it "#authentication_status_ok? true if no type, default is Valid" do
        @auth.update_attribute(:status, "Valid")
        expect(@ems.authentication_status_ok?).to be_truthy
      end

      it "#authentication_status_ok? true if no type, default is Valid and second one is Invalid" do
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.build(:authentication, :authtype => :some_type, :status => "Invalid")
        expect(@ems.authentication_status_ok?).to be_truthy
      end

      it "#authentication_status_ok? false if no type, default is Invalid and second one is Valid" do
        @auth.update_attribute(:status, "Invalid")
        @ems.authentications << FactoryGirl.build(:authentication, :authtype => :some_type, :status => "Valid")
        expect(@ems.authentication_status_ok?).to be_falsey
      end

      it "#authentication_status_ok? true if type is Valid" do
        @auth.update_attribute(:status, "Invalid")
        @ems.authentications << FactoryGirl.build(:authentication, :authtype => :some_type, :status => "Valid")
        expect(@ems.authentication_status_ok?(:some_type)).to be_truthy
      end

      it "#authentication_status_ok? false if type is Invalid" do
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.build(:authentication, :authtype => :some_type, :status => "Invalid")
        expect(@ems.authentication_status_ok?(:some_type)).to be_falsey
      end

      it "should return 'Invalid' authentication_status with one valid, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one error, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Error")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one unreachable, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Unreachable")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one incomplete, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Error' authentication_status with one incomplete, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Error' authentication_status with one valid, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Valid' authentication_status with both valid" do
        highest = "Valid"
        @auth.update_attribute(:status, highest)
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Incomplete' authentication_status with one valid, one incomplete" do
        highest = "Incomplete"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'None' authentication_status with one nil, one nil" do
        highest = nil
        @auth.update_attribute(:status, nil)
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq('None')
      end

      it "should return 'None' authentication_status with no authentications" do
        @ems.authentications = []
        expect(@ems.authentication_status).to eq('None')
      end

      it "should have credentials" do
        expect(@ems.has_credentials?).to be_truthy
      end

      it "should have missing credentials if userid nil" do
        @auth.update_attribute(:userid, nil)
        expect(@ems.missing_credentials?).to be_truthy
      end

      it "should have missing credentials if ems's authentication is nil" do
        @ems.authentications = []
        expect(@ems.missing_credentials?).to be_truthy
      end

      it "should have correct userid" do
        expect(@ems.authentication_userid).to eq('testuser')
      end

      it "should have correct decrypted password" do
        expect(@ems.authentication_password).to eq('secret')
      end

      it "should have correct encrypted password" do
        expect(@ems.authentication_password_encrypted).to be_encrypted("secret")
      end

      it "should call password_encrypted= when calling password=" do
        expect(@auth).to receive(:password_encrypted=)
        @auth.password = "blah2"
      end

      it "should call password_encrypted when calling password" do
        expect(@auth).to receive(:password_encrypted)
        @auth.password
      end

      it "should not raise :changed event or queue authentication_check if creds unchanged" do
        expect(@auth).to receive(:raise_event).with(:changed).never
        expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:authentication_check_types_queue).never
        @auth.send(:after_authentication_changed)
      end

      it "should have default authentication_type?" do
        expect(@host.has_authentication_type?(:default)).to be_truthy
        expect(@ems.has_authentication_type?(:default)).to be_truthy
      end

      it "should have authentications" do
        expect(@host.authentications.length).to be > 0
        expect(@ems.authentications.length).to be > 0
      end

      it "Host#authentication_check_types_queue with [:ssh, :default], :remember_host => true is passed down to verify_credentials" do
        @host.authentication_check_types_queue([:ssh, :default], :remember_host => true)
        conditions = {:class_name => @host.class.base_class.name, :instance_id => @host.id, :method_name => 'authentication_check_types', :role => @host.authentication_check_role}
        queued_auth_checks = MiqQueue.where(conditions)
        expect(queued_auth_checks.length).to eq(1)
        expect_any_instance_of(Host).to receive(:verify_credentials).with(:default, :remember_host => true)
        expect_any_instance_of(Host).to receive(:verify_credentials).with(:ssh, :remember_host => true)
        queued_auth_checks.first.deliver
      end

      it "Ems#authentication_check_types_queue with :default, :test => true will not pass :remember_host => true to verify_credentials call" do
        @ems.authentication_check_types_queue(:default, :remember_host => true)
        conditions = {:class_name => @ems.class.base_class.name, :instance_id => @ems.id, :method_name => 'authentication_check_types', :role => @ems.authentication_check_role}
        queued_auth_checks = MiqQueue.where(conditions)
        expect(queued_auth_checks.length).to eq(1)
        expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:verify_credentials).with(:default)
        queued_auth_checks.first.deliver
      end

      context "#authentication_check" do
        it "updates status by default" do
          allow(@host).to receive(:missing_credentials?).and_return(true)
          @host.authentication_check
          expect(@host.authentication_type(:default).status).to eq('Incomplete')
        end

        it "raises auth event" do
          allow(@host).to receive(:missing_credentials?).and_return(true)
          @host.authentication_check

          event = MiqQueue.where(:class_name => "MiqEvent").where(:method_name => "raise_evm_event").first
          args = [[@host.class.name, @host.id], 'host_auth_incomplete', {}]
          expect(event.args).to eq args
        end

        it "(:save => true) updates status" do
          allow(@host).to receive(:verify_credentials).and_return(true)
          @host.authentication_check(:save => true)
          expect(@host.authentication_type(:default).status).to eq("Valid")
          expect(MiqQueue.where(:class_name => "MiqEvent").where(:method_name => "raise_evm_event").count).to eq(1)
        end

        it "(:save => false) does not update status" do
          allow(@host).to receive(:missing_credentials?).and_return(false)
          @host.authentication_check(:save => false)
          expect(@host.authentication_type(:default).status).to be_nil
          expect(MiqQueue.where(:class_name => "MiqEvent").where(:method_name => "raise_evm_event").count).to eq(0)
        end

        it "missing credentials" do
          allow(@host).to receive(:missing_credentials?).and_return(true)
          expect(@host.authentication_check).to eq([false, "Missing credentials"])
        end

        it "verify_credentials fails" do
          allow(@host).to receive(:verify_credentials).and_return(false)
          expect(@host.authentication_check).to eq([false, "Unknown reason"])
        end

        it "verify_credentials successful" do
          allow(@host).to receive(:verify_credentials).and_return(true)
          expect(@host.authentication_check).to eq([true, ""])
        end

        it "verify_credentials raising 'Unreachable' error" do
          allow(@host).to receive(:verify_credentials).and_raise(MiqException::MiqUnreachableError)
          expect(@host.authentication_check).to eq([false, "MiqException::MiqUnreachableError"])
        end

        it "verify_credentials raising invalid credentials" do
          allow(@host).to receive(:verify_credentials).and_raise(MiqException::MiqInvalidCredentialsError)
          expect(@host.authentication_check).to eq([false, "MiqException::MiqInvalidCredentialsError"])
        end

        it "verify_credentials raising login error" do
          allow(@host).to receive(:verify_credentials).and_raise(MiqException::MiqEVMLoginError)
          expect(@host.authentication_check).to eq([false, "Login failed due to a bad username or password."])
        end

        it "verify_credentials raising an unexpected error" do
          allow(@host).to receive(:verify_credentials).and_raise(RuntimeError)
          expect(@host.authentication_check).to eq([false, "RuntimeError"])
        end
      end

      it "should return nothing if update_authentication is passed no data" do
        expect(@ems.update_authentication({})).to be_nil
      end

      it "should have new user/password to apply" do
        expect(@orig_ems_user).not_to equal @data[:default][:userid]
        expect(@orig_ems_pwd).not_to equal @data[:default][:password]
      end

      it "should have existing user/pass matching cached one" do
        expect(@ems.auth_user_pwd(:default)).to eq([@orig_ems_user, @orig_ems_pwd])
      end

      it "should NOT change credentials if save false" do
        @ems.update_authentication(@data, :save => false)
        expect(@ems.reload.auth_user_pwd(:default)).to eq([@orig_ems_user, @orig_ems_pwd])
      end

      it "should change credentials if save nil" do
        @ems.update_authentication(@data)
        expect(@ems.auth_user_pwd(:default)).to eq([@data[:default][:userid], @data[:default][:password]])
      end

      it "should change credentials if save true" do
        @ems.update_authentication(@data, :save => true)
        expect(@ems.auth_user_pwd(:default)).to eq([@data[:default][:userid], @data[:default][:password]])
      end

      it "should NOT call after_authentication_changed when calling update_authentication with save false" do
        expect_any_instance_of(Authentication).to receive(:after_authentication_changed).never
        @ems.update_authentication(@data, :save => false)
      end

      it "should call after_authentication_changed when calling update_authentication with save nil" do
        expect_any_instance_of(Authentication).to receive(:after_authentication_changed)
        @ems.update_authentication(@data)
      end

      it "should call after_authentication_changed when calling update_authentication with save true" do
        expect_any_instance_of(Authentication).to receive(:after_authentication_changed)
        @ems.update_authentication(@data, :save => true)
      end

      it "should queue a raise authentication change event when calling update_authentication" do
        @ems.update_authentication(@data, :save => true)
        events = MiqQueue.where(:class_name => "MiqEvent", :method_name => "raise_evm_event")
        args = [[@ems.class.name, @ems.id], 'ems_auth_changed', {}]
        expect(events.any? { |e| e.args == args }).to be_truthy, "#{events.inspect} with args: #{args.inspect} expected"
      end

      context "with credentials_changed_on set to now and jump 1 minute" do
        before(:each) do
          @before = Time.now.utc
          @auth.update_attribute(:credentials_changed_on, @before)
          Timecop.travel 1.minute
        end

        after(:each) do
          Timecop.return
        end

        it "should update credentials_changed_on when updating authentications" do
          @ems.update_authentication(@data, :save => true)
          after = @auth.credentials_changed_on
          expect(after).to be > @before
        end

        it "should update credentials_changed_on when changing userid/password and saving" do
          @auth.update_attribute(:userid, 'blah')
          after = @auth.credentials_changed_on
          expect(after).to be > @before
        end
      end

      context "with saved authentications" do
        before(:each) do
          @ems.update_authentication(@data, :save => true)
          @conditions = {:class_name => @ems.class.base_class.name, :instance_id => @ems.id, :method_name => 'authentication_check_types', :role => @ems.authentication_check_role}
          @queued_auth_checks = MiqQueue.where(@conditions)
        end

        it "should queue validation of authentication" do
          expect(@queued_auth_checks.length).to eq(1)
        end

        it "should queue only 1 auth validation per ci" do
          @ems.authentication_check_types_queue(:default)
          @ems.authentication_check_types_queue(:default)
          expect(MiqQueue.where(@conditions).count).to eq(1)
        end

        it "should call authentication_check when processing the validation check" do
          expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:authentication_check)
          @queued_auth_checks.first.deliver
        end
      end

      context "creds unchanged" do
        before(:each) do
          @data[:default][:userid] = @orig_ems_user
          @data[:default][:password] = @orig_ems_pwd
        end

        it "should NOT change credentials" do
          @ems.update_authentication(@data, :save => true)
          expect(@ems.auth_user_pwd(:default)).to eq([@orig_ems_user, @orig_ems_pwd])
        end

        it "should not call after_authentication_changed" do
          expect_any_instance_of(Authentication).to receive(:after_authentication_changed).never
          expect_any_instance_of(Authentication).to receive(:set_credentials_changed_on).never
          @ems.update_authentication(@data, :save => true)
        end

        it "should not delete" do
          @ems.update_authentication(@data, :save => true)
          expect(@ems.authentications.length).to eq(1)
        end
      end

      context "creds incomplete userid" do
        before(:each) do
          @data[:default][:userid] = nil
          @data[:default][:password] = @orig_ems_pwd
        end

        it "should not delete if save false" do
          @ems.update_authentication(@data, :save => false)
          expect(@ems.auth_user_pwd(:default)).to eq([@orig_ems_user, @orig_ems_pwd])
        end

        it "should not call after_authentication_changed" do
          expect_any_instance_of(Authentication).to receive(:after_authentication_changed).never
          expect_any_instance_of(Authentication).to receive(:set_credentials_changed_on).never
          @ems.update_authentication(@data, :save => true)
        end

        it "should delete" do
          @ems.update_authentication(@data, :save => true)
          expect(@ems.has_authentication_type?(:default)).not_to be_truthy
        end
      end

      context "userid blanked out" do
        before do
          @data[:default][:userid] = ""
          @data[:default][:password] = "abc"
        end

        it "deletes the record if userid is blank" do
          @host.update_authentication(@data, :save => true)
          expect(@host.auth_user_pwd(:default)).to be_nil
          expect(@host.has_authentication_type?(:default)).not_to be_truthy
        end
      end

      context "password blanked out" do
        before do
          @data[:default][:userid] = @orig_ems_user
          @data[:default][:password] = ""
        end

        it "sets the password to ''" do
          @host.update_authentication(@data, :save => true)
          expect(@host.has_authentication_type?(:default)).to be_truthy
          expect(@host.auth_user_pwd(:default)).to eq([@orig_ems_user, ''])
        end
      end
    end
  end
end
