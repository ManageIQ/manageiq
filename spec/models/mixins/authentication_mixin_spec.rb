RSpec.describe AuthenticationMixin do
  include Spec::Support::ArelHelper

  let(:host)            { FactoryBot.create(:host) }
  let(:invalid_auth)    { FactoryBot.create(:authentication, :resource => host, :status => "Invalid") }
  let(:valid_auth)      { FactoryBot.create(:authentication, :resource => host, :status => "Valid") }
  let(:authentications) { [invalid_auth, valid_auth] }

  let(:test_class_instance) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "vms"
      include AuthenticationMixin
    end.new
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
        allow(test_class_instance).to receive_messages(:authentication_best_fit => nil)
        expect(test_class_instance.send(method)).to eq(expected)
      end

      it "no #{required_field}" do
        allow(test_class_instance).to receive_messages(:authentication_best_fit => double(required_field => nil))
        expect(test_class_instance.send(method)).to eq(expected)
      end

      it "blank #{required_field}" do
        allow(test_class_instance).to receive_messages(:authentication_best_fit => double(required_field => ""))
        expect(test_class_instance.send(method)).to eq(expected)
      end

      it "normal case" do
        allow(test_class_instance).to receive_messages(:authentication_best_fit => double(required_field => "test"))

        expected = case method
                   when :has_credentials?
                     true
                   when :missing_credentials?
                     false
                   else
                     "test"
                   end

        expect(test_class_instance.send(method)).to eq(expected)
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
        data    = {:test => {:userid => "test_user"}}
        options = {:required => :userid}
        test_class_instance.update_authentication(data, options)
        expect(test_class_instance.has_authentication_type?(:test)).to be_truthy
      end

      it "raises when blank" do
        data    = {:test => {:userid => "test_user"}}
        options = {:required => :password}
        expect { test_class_instance.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end

    context "requires both fields" do
      it "saves when populated" do
        data    = {:test => {:userid => "test_user", :password => "test_pass"}}
        options = {:required => [:userid, :password]}
        test_class_instance.update_authentication(data, options)
        expect(test_class_instance.has_authentication_type?(:test)).to be_truthy
      end

      it "raises when blank" do
        data    = {:test => {:userid => "test_user"}}
        options = {:required => [:userid, :password]}
        expect { test_class_instance.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end
  end

  context "authorization event and check for container providers" do
    before do
      zone = FactoryBot.create(:zone)
      allow(MiqServer).to receive(:my_zone).and_return(zone.name)
    end

    it "should be triggered for kubernetes" do
      auth = AuthToken.new(:name => "bearer", :auth_key => "valid-token")
      FactoryBot.create(:ems_kubernetes, :authentications => [auth])

      expect(MiqQueue.count).to eq(2)
      expect(MiqQueue.find_by(:method_name => 'raise_evm_event')).not_to be_nil
      expect(MiqQueue.find_by(:method_name => 'authentication_check_types')).not_to be_nil
    end

    it "should be triggered for openshift" do
      auth = AuthToken.new(:name => "bearer", :auth_key => "valid-token")
      FactoryBot.create(:ems_openshift, :authentications => [auth])

      expect(MiqQueue.count).to eq(2)
      expect(MiqQueue.find_by(:method_name => 'raise_evm_event')).not_to be_nil
      expect(MiqQueue.find_by(:method_name => 'authentication_check_types')).not_to be_nil
    end
  end

  it "#exponential_delay" do
    expect(test_class_instance.exponential_delay(0)).to eq(1)
    expect(test_class_instance.exponential_delay(1)).to eq(2)
    expect(test_class_instance.exponential_delay(2)).to eq(4)
    expect(test_class_instance.exponential_delay(3)).to eq(8)
    expect(test_class_instance.exponential_delay(4)).to eq(16)
    expect(test_class_instance.exponential_delay(5)).to eq(32)
  end

  it "#authentication_check_retry_deliver_on" do
    Timecop.freeze(Time.new(2015, 1, 2, 0, 0, 0, 0)) do
      expect(test_class_instance.authentication_check_retry_deliver_on(nil)).to be_nil
      expect(test_class_instance.authentication_check_retry_deliver_on(0)).to   be_nil

      expect(test_class_instance.authentication_check_retry_deliver_on(1)).to eq(Time.now.utc + 1.minute)
      expect(test_class_instance.authentication_check_retry_deliver_on(5)).to eq(Time.now.utc + 16.minutes)

      # 6 is >= MAX_ATTEMPTS and shouldn't be called
      expect(test_class_instance.authentication_check_retry_deliver_on(6)).to eq(Time.now.utc + 32.minutes)
    end
  end

  context "#retry_scheduled_authentication_check" do
    let(:host) do
      EvmSpecHelper.local_miq_server
      FactoryBot.create(:host_with_authentication).tap { MiqQueue.destroy_all }
    end

    it "works" do
      host.authentications.first.update(:status => "Error")
      host.reload.retry_scheduled_authentication_check(:default, :attempt => 1)
      q = MiqQueue.find_by(:method_name => 'authentication_check_types', :instance_id => host.id)
      expect(q.args.last).to eq(:attempt => 2)
    end

    it "doesn't queue on Invalid credentials" do
      host.authentications.first.update(:status => "Invalid")
      host.retry_scheduled_authentication_check(:default, :attempt => 1)
      expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :instance_id => host.id)).to be_falsey
    end

    it "doesn't queue without an authentication" do
      host.authentications.destroy_all
      host.retry_scheduled_authentication_check(:default, :attempt => 1)
      expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :instance_id => host.id)).to be_falsey
    end
  end

  context "with server and zone" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
      @data = {:default => {:userid => "test", :password => "blah"}}
    end

    context "with multiple zones, emses, and hosts" do
      before do
        @zone1 = @miq_server.zone
        @zone2 = FactoryBot.create(:zone, :name => 'test1')
        @ems1  = FactoryBot.create(:ems_vmware_with_authentication, :zone => @zone1)
        @ems2  = FactoryBot.create(:ems_vmware_with_authentication, :zone => @zone2)
        @host1 = FactoryBot.create(:host_with_authentication, :ext_management_system => @ems1)
        @host2 = FactoryBot.create(:host_with_authentication, :ext_management_system => @ems2)

        # Destroy any queued auth checks from creating the new CI's with authentications
        MiqQueue.destroy_all
      end

      context ".authentication_check_schedule" do
        it "will specify attempt in queue message" do
          Host.authentication_check_schedule
          msg = MiqQueue.find_by(:method_name => 'authentication_check_types', :class_name => 'Host')
          expect(msg.args.last).to eq(:attempt => 1)
        end

        it "will enqueue for Ems's for current zone" do
          ExtManagementSystem.authentication_check_schedule
          expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :zone => @ems1.my_zone)).to be_truthy
          expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id).count).to eq(0)
        end

        it "will enqueue for role 'ems_operations' for current zone" do
          ExtManagementSystem.authentication_check_schedule
          expect(MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :role => @ems1.authentication_check_role)).to be_truthy
          expect(MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id).count).to eq(0)
        end

        context "retry" do
          let(:queue_conditions) { {:method_name => 'authentication_check_types', :class_name => 'Host'} }

          it "works" do
            time = Time.new(2015, 1, 2, 0, 0, 0, 0)
            Timecop.freeze(time) do
              Host.authentication_check_schedule
              allow_any_instance_of(Host).to receive(:verify_credentials).and_raise
              msg = MiqQueue.find_by(queue_conditions)
              msg.delivered(*msg.deliver)

              # attempt 2, 3, 4, 5 should requeue, 6 should NOT
              2.upto(6) do |counter|
                if counter < 6
                  minutes = (2**(counter - 1)).minutes
                  msg = MiqQueue.find_by(queue_conditions)
                  expect(msg.args.last).to eq(:attempt => counter)
                  expect(msg.deliver_on).to be_within(0.01).of(time + minutes)

                  msg.delivered(*msg.deliver)
                else
                  expect(MiqQueue).not_to exist(queue_conditions)
                end
              end
            end
          end

          it "skips when existing attempt is in the queue" do
            Host.authentication_check_schedule
            messages = MiqQueue.where(queue_conditions)
            expect(messages.count).to eq(1)
            expect(messages.first.args.last).to eq(:attempt => 1)

            Host.authentication_check_schedule
            messages = MiqQueue.where(queue_conditions)
            expect(messages.count).to eq(1)
            expect(messages.first.args.last).to eq(:attempt => 1)
          end

          it "skips when another attempt is in the queue" do
            Host.authentication_check_schedule
            msg = MiqQueue.where(queue_conditions).first
            msg.args.last[:attempt] = 2
            msg.save

            Host.authentication_check_schedule
            messages = MiqQueue.where(:method_name => 'authentication_check_types', :class_name => 'Host')
            expect(messages.count).to eq(1)
            expect(messages.first.args.last).to eq(:attempt => 2)
          end

          it "filters out attempt from the authentication_check call" do
            expect(@host1).to receive(:authentication_check).with(nil, hash_excluding(:attempt)).and_return([true, ""])
            expect(@host1).to receive(:authentication_check).with(nil, hash_including(:attempt)).and_return([true, ""]).never
            @host1.authentication_check_types(:attempt => 1)
          end
        end
      end
    end

    context ".validate_credentials_task" do
      let(:args) { %w(userid password foo) }
      let(:queue_opts) do
        {
          :args        => [*args],
          :class_name  => "ExtManagementSystem",
          :method_name => "raw_connect?",
          :queue_name  => "generic",
          :role        => "ems_operations",
          :zone        => 'zone'
        }
      end
      let(:task_opts) do
        {
          :action => "Validate EMS Provider Credentials",
          :userid => 'userid'
        }
      end

      it "returns success with no error message" do
        ok_task = FactoryBot.create(:miq_task, :status => 'Ok')
        allow(MiqTask).to receive(:generic_action_with_callback).with(task_opts, queue_opts).and_return(1)
        allow(MiqTask).to receive(:wait_for_taskid).with(1, :timeout => 30).and_return(ok_task)

        expect(ExtManagementSystem.validate_credentials_task(args, 'userid', 'zone')).to eq([true, nil])
      end

      it "returns failure with an error message" do
        message = 'Login failed due to a bad username or password.'
        error_task = FactoryBot.create(:miq_task, :status => 'Error', :message => message)
        allow(MiqTask).to receive(:generic_action_with_callback).with(task_opts, queue_opts).and_return(1)
        allow(MiqTask).to receive(:wait_for_taskid).with(1, :timeout => 30).and_return(error_task)

        expect(ExtManagementSystem.validate_credentials_task(args, 'userid', 'zone')).to eq([false, message])
      end
    end

    context "with a host and ems" do
      before do
        @host         = FactoryBot.create(:host_vmware_esx_with_authentication)
        @host_no_auth = FactoryBot.create(:host_vmware_esx)
        @ems          = FactoryBot.create(:ems_vmware_with_authentication)
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
        @ems.authentications << FactoryBot.build(:authentication, :authtype => :some_type, :status => "Invalid")
        expect(@ems.authentication_status_ok?).to be_truthy
      end

      it "#authentication_status_ok? false if no type, default is Invalid and second one is Valid" do
        @auth.update_attribute(:status, "Invalid")
        @ems.authentications << FactoryBot.build(:authentication, :authtype => :some_type, :status => "Valid")
        expect(@ems.authentication_status_ok?).to be_falsey
      end

      it "#authentication_status_ok? true if type is Valid" do
        @auth.update_attribute(:status, "Invalid")
        @ems.authentications << FactoryBot.build(:authentication, :authtype => :some_type, :status => "Valid")
        expect(@ems.authentication_status_ok?(:some_type)).to be_truthy
      end

      it "#authentication_status_ok? false if type is Invalid" do
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryBot.build(:authentication, :authtype => :some_type, :status => "Invalid")
        expect(@ems.authentication_status_ok?(:some_type)).to be_falsey
      end

      it "should return 'Invalid' authentication_status with one valid, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one error, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Error")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one unreachable, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Unreachable")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Invalid' authentication_status with one incomplete, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Error' authentication_status with one incomplete, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Error' authentication_status with one valid, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Valid' authentication_status with both valid" do
        highest = "Valid"
        @auth.update_attribute(:status, highest)
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'Incomplete' authentication_status with one valid, one incomplete" do
        highest = "Incomplete"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
        expect(@ems.authentication_status).to eq(highest)
      end

      it "should return 'None' authentication_status with one nil, one nil" do
        highest = nil
        @auth.update_attribute(:status, nil)
        @ems.authentications << FactoryBot.create(:authentication, :status => highest)
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
        types   = %i(ssh default)
        options = {:remember_host => true}
        @host.authentication_check_types_queue(types, options)
        conditions = {:class_name => @host.class.base_class.name, :instance_id => @host.id, :method_name => 'authentication_check_types', :role => @host.authentication_check_role}
        queued_auth_check = MiqQueue.where(conditions).first
        expect(queued_auth_check.args.first).to  eq(types)
        expect(queued_auth_check.args.second).to eq(options)
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
          @host.authentications.first.update(:status => nil) # start unauthorized
          allow(@host).to receive(:verify_credentials).and_return(true)
          @host.authentication_check(:save => true)
          expect(@host.authentication_type(:default).status).to eq("Valid")
          expect(MiqQueue.where(:class_name => "MiqEvent").where(:method_name => "raise_evm_event").count).to eq(1)
        end

        it "(:save => false) does not update status" do
          @host.authentications.first.update(:status => nil) # start unauthorized
          allow(@host).to receive(:missing_credentials?).and_return(false)
          @host.authentication_check(:save => false)
          expect(@host.authentication_type(:default).status).to be_nil
          expect(MiqQueue.where(:class_name => "MiqEvent").where(:method_name => "raise_evm_event").count).to eq(0)
        end

        it "missing credentials" do
          expect(@host_no_auth.authentication_check).to eq([false, "Missing credentials"])
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
        before do
          @before = Time.now.utc
          @auth.update_attribute(:credentials_changed_on, @before)
          Timecop.travel 1.minute
        end

        after do
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
        before do
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
      end

      context "creds unchanged" do
        before do
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
        before do
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

      context "password changes" do
        let(:current_password) { "current_pass" }
        let(:new_password) { "new_pass" }
        let(:confirm_password) { "new_pass" }

        context "#change_password_queue" do
          it 'queues an update task with update_volume_queue' do
            task_id = @ems.change_password_queue('test_user', current_password, new_password)

            expect(MiqTask.find(task_id)).to have_attributes(
              :name   => "Changing the password for Physical Provider named '#{@ems.name}'",
              :state  => "Queued",
              :status => "Ok"
            )

            expect(MiqQueue.where(:class_name => @ems.class.name).first).to have_attributes(
              :class_name  => @ems.class.name,
              :method_name => 'change_password',
              :role        => 'ems_operations',
              :queue_name  => @ems.queue_name_for_ems_operations,
              :zone        => @ems.my_zone,
              :args        => [current_password, new_password, :default]
            )
          end
        end

        context "#change_password" do
          it "should fail if some param is blank" do
            current_password = ""
            allow(@ems).to receive(:supports?).with(:change_password) { true }

            expect { @ems.change_password(current_password, new_password, confirm_password) }
              .to raise_error(MiqException::Error, "Please, fill the current_password and new_password fields.")
          end

          it "should fail if the provider doesn't support this operation" do
            expect { @ems.change_password(current_password, new_password, confirm_password) }
              .to raise_error(MiqException::Error, "Change Password is not supported for #{@ems.class.description} provider")
          end

          it "should update the provider password" do
            allow(@ems).to receive(:raw_change_password) { true }
            allow(@ems).to receive(:supports?).with(:change_password) { true }

            expect(@ems.change_password(current_password, new_password, confirm_password)).to be_truthy
          end
        end
      end
    end
  end

  describe "#authentication_status_severity_level" do
    it "uses the least valid status" do
      EvmSpecHelper.local_miq_server
      authentications
      expect(host.authentication_status_severity_level.status).to eq("Invalid")
    end
  end

  describe "#authentication_status" do
    before do
      EvmSpecHelper.local_miq_server
    end

    context "with no authentications" do
      before { host }

      it "is nil with sql" do
        expect(virtual_column_sql_value(Host, "authentication_status")).to be_nil
      end

      it "is 'None' with pure ruby (via relations)" do
        expect(host.authentication_status).to eq("None")
      end

      it "is 'None' when accessed via ruby, but fetched via sql" do
        fetched_host = Host.select(:id, :authentication_status).first
        expect(fetched_host.attributes[:authentication_status]).to be_nil
        expect(fetched_host.authentication_status).to eq("None")
      end
    end

    context "with an unrelated and existing valid authentication" do
      let(:id_start_point)        { [Host.order(:id).last&.id.to_i, ExtManagementSystem.order(:id).last&.id.to_i].max }
      let(:host)                  { FactoryBot.create(:host, :id => ext_management_system.id) }
      let(:ext_management_system) { FactoryBot.create(:ext_management_system, :authtype => "default", :id => id_start_point + 1) }

      before { host }

      it "is nil with sql" do
        expect(virtual_column_sql_value(Host, "authentication_status")).to be_nil
      end

      it "is 'None' with pure ruby (via relations)" do
        expect(host.authentication_status).to eq("None")
      end

      it "is 'None' when accessed via ruby, but fetched via sql" do
        fetched_host = Host.select(:id, :authentication_status).first
        expect(fetched_host.attributes[:authentication_status]).to be_nil
        expect(fetched_host.authentication_status).to eq("None")
      end
    end

    context "with a valid authentication" do
      before { valid_auth }

      it "is 'Valid' with sql" do
        h = Host.select(:id, :authentication_status).first

        expect do
          expect(h.authentication_status).to eq("Valid")
        end.to_not make_database_queries
        expect(h.association(:authentication_status_severity_level)).not_to be_loaded
      end

      it "is 'Valid' with ruby" do
        h = Host.first # clean host record

        expect(h.authentication_status).to eq("Valid")
        expect(h.association(:authentication_status_severity_level)).to be_loaded
      end
    end

    context "with a valid and invalid authentication" do
      before { authentications }

      it "is 'Invalid' with sql" do
        h = Host.select(:id, :authentication_status).first

        expect do
          expect(h.authentication_status).to eq("Invalid")
        end.to_not make_database_queries
        expect(h.association(:authentication_status_severity_level)).not_to be_loaded
      end

      it "is 'Valid' with ruby" do
        h = Host.first # clean host record

        expect(h.authentication_status).to eq("Invalid")
        expect(h.association(:authentication_status_severity_level)).to be_loaded
      end
    end
  end
end
