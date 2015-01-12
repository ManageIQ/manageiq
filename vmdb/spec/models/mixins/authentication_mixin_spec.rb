require "spec_helper"

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
        when :authentication_valid?
          false
        when :authentication_invalid?
          true
        else
          nil
        end
      end

      it "no authentication" do
        t = TestClass.new
        t.stub(:authentication_best_fit => nil)
        t.send(method).should == expected
      end

      it "no #{required_field}" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => nil))
        t.send(method).should == expected
      end

      it "blank #{required_field}" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => ""))
        t.send(method).should == expected
      end

      it "normal case" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => "test"))

        expected = case method
        when :authentication_valid?
          true
        when :authentication_invalid?
          false
        else
          "test"
        end

        t.send(method).should == expected
      end
    end
  end

  include_examples "authentication_components", :authentication_password, :password
  include_examples "authentication_components", :authentication_userid, :userid
  include_examples "authentication_components", :authentication_password_encrypted, :password_encrypted
  include_examples "authentication_components", :authentication_valid?, :userid
  include_examples "authentication_components", :authentication_invalid?, :userid

  context "required fields" do
    context "requires one field" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => :userid}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_true
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => :password}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end

    context "requires both fields" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user", :password => "test_pass"}}
        options = {:required => [:userid, :password]}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_true
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => [:userid, :password]}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end
  end

  context "with server and zone" do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server_not_master, :guid => @guid, :zone => @zone)
      MiqServer.my_server(true)
      @data = {:default => {:userid => "test", :password => "blah"}}
    end

    context "with multiple zones, emses, and hosts" do
      before(:each) do
        @zone1 = @zone
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
        MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host1.id, :zone => @host1.my_zone).should be_true
        MiqQueue.count(:conditions => {:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host2.id}).should == 0
      end

      it "Ems.authentication_check_schedule will enqueue for current zone" do
        ExtManagementSystem.authentication_check_schedule
        MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :zone => @ems1.my_zone ).should be_true
        MiqQueue.count(:conditions => {:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id} ).should == 0
      end

      it "Host.authentication_check_schedule will enqueue for role 'smartstate' for current zone" do
        Host.authentication_check_schedule
        MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host1.id, :zone => @host1.my_zone, :role => @host1.authentication_check_role).should be_true
        MiqQueue.count(:conditions => {:method_name => 'authentication_check_types', :class_name => 'Host', :instance_id => @host2.id }).should ==0
      end

      it "Ems.authentication_check_schedule will enqueue for role 'ems_operations' for current zone" do
        ExtManagementSystem.authentication_check_schedule
        MiqQueue.exists?(:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems1.id, :role => @ems1.authentication_check_role).should be_true
        MiqQueue.count(:conditions => {:method_name => 'authentication_check_types', :class_name => 'ExtManagementSystem', :instance_id => @ems2.id } ).should == 0
      end
    end

    context "with a host and ems" do
      before(:each) do
        @host = FactoryGirl.create(:host_with_authentication)
        @ems  = FactoryGirl.create(:ems_vmware_with_authentication)
        MiqQueue.destroy_all
        @auth = @ems.authentication_best_fit(:default)
        @orig_ems_user, @orig_ems_pwd = @ems.auth_user_pwd(:default)
      end

      it "should return 'Invalid' authentication_status with one valid, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Invalid' authentication_status with one error, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Error")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Invalid' authentication_status with one unreachable, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Unreachable")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Invalid' authentication_status with one incomplete, one invalid" do
        highest = "Invalid"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Error' authentication_status with one incomplete, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Incomplete")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Error' authentication_status with one valid, one error" do
        highest = "Error"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Valid' authentication_status with both valid" do
        highest = "Valid"
        @auth.update_attribute(:status, highest)
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'Incomplete' authentication_status with one valid, one incomplete" do
        highest = "Incomplete"
        @auth.update_attribute(:status, "Valid")
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == highest
      end

      it "should return 'None' authentication_status with one nil, one nil" do
        highest = nil
        @auth.update_attribute(:status, nil)
        @ems.authentications << FactoryGirl.create(:authentication, :status => highest)
        @ems.authentication_status.should == 'None'
      end

      it "should return 'None' authentication_status with no authentications" do
        @ems.authentications = []
        @ems.authentication_status.should == 'None'
      end

      it "should have valid_authentication" do
        @ems.authentication_valid?.should be_true
      end

      it "should have invalid authentication if userid nil" do
        @auth.update_attribute(:userid, nil)
        @ems.authentication_invalid?.should be_true
      end

      it "should have invalid authentication ems's authentication is nil" do
        @ems.authentications = []
        @ems.authentication_invalid?.should be_true
      end

      it "should have correct userid" do
        @ems.authentication_userid.should == 'testuser'
      end

      it "should have correct decrypted password" do
        @ems.authentication_password.should == 'secret'
      end

      it "should have correct encrypted password" do
        expect(@ems.authentication_password_encrypted).to be_encrypted("secret")
      end

      it "should call password_encrypted= when calling password=" do
        @auth.should_receive(:password_encrypted=)
        @auth.password = "blah2"
      end

      it "should call password_encrypted when calling password" do
        @auth.should_receive(:password_encrypted)
        @auth.password
      end

      it "should not raise :changed event or queue authentication_check if creds unchanged" do
        @auth.should_receive(:raise_event).with(:changed).never
        EmsVmware.any_instance.should_receive(:authentication_check_types_queue).never
        @auth.send(:after_authentication_changed)
      end

      it "should have default authentication_type?" do
        @host.has_authentication_type?(:default).should be_true
        @ems.has_authentication_type?(:default).should be_true
      end

      it "should have authentications" do
        @host.authentications.length.should > 0
        @ems.authentications.length.should  > 0
      end

      it "Host#authentication_check_types_queue with [:ssh, :default], :remember_host => true is passed down to verify_credentials" do
        @host.authentication_check_types_queue([:ssh, :default], :remember_host => true)
        conditions = {:class_name => @host.class.name, :instance_id => @host.id, :method_name => 'authentication_check_types', :role => @host.authentication_check_role}
        queued_auth_checks = MiqQueue.find(:all, :conditions => conditions)
        queued_auth_checks.length.should == 1
        Host.any_instance.should_receive(:verify_credentials).with(:default, :remember_host => true)
        Host.any_instance.should_receive(:verify_credentials).with(:ssh, :remember_host => true)
        queued_auth_checks.first.deliver
      end

      it "Ems#authentication_check_types_queue with :default, :test => true will not pass :remember_host => true to verify_credentials call" do
        @ems.authentication_check_types_queue(:default, :remember_host => true)
        conditions = {:class_name => @ems.class.base_class.name, :instance_id => @ems.id, :method_name => 'authentication_check_types', :role => @ems.authentication_check_role}
        queued_auth_checks = MiqQueue.find(:all, :conditions => conditions)
        queued_auth_checks.length.should == 1
        EmsVmware.any_instance.should_receive(:verify_credentials).with(:default)
        queued_auth_checks.first.deliver
      end

      context "with host invalid authentication due to no authentication row or incomplete userid" do
        before(:each) do
          @host.stub(:authentication_valid?).and_return(false)
        end

        it "should return false when calling authentication_check" do
          @host.authentication_check.should_not be_true
        end

        it "should set the host's authentication as 'Incomplete' when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Incomplete'
        end

        it "should queue a raise authentication incomplete event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_incomplete', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems invalid authentication due to no authentication row or incomplete userid" do
        before(:each) do
          @ems.stub(:authentication_valid?).and_return(false)
        end

        it "should return false when calling authentication_check" do
          @ems.authentication_check.should_not be_true
        end

        it "should set the ems's authentication as 'Incomplete' when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Incomplete'
        end

        it "should queue a raise authentication incomplete event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_incomplete', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with host verify_credentials failing due to invalid credentials" do
        before(:each) do
          @host.stub(:verify_credentials).and_return(false)
        end

        it "should return false when calling authentication_check" do
          @host.authentication_check.should_not be_true
        end

        it "should set the host's authentication as 'Invalid' when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Invalid'
        end

        it "should queue a raise authentication invalid event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_invalid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems verify_credentials failing due to invalid credentials" do
        before(:each) do
          @ems.stub(:verify_credentials).and_return(false)
        end

        it "should return false when calling authentication_check" do
          @ems.authentication_check.should_not be_true
        end

        it "should set the ems's authentication as 'Invalid' when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Invalid'
        end

        it "should queue a raise authentication invalid event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_invalid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with host verify_credentials successful" do
        before(:each) do
          @host.stub(:verify_credentials).and_return(true)
        end

        it "should return true when calling authentication_check" do
          @host.authentication_check.should be_true
        end

        it "should set the host's authentication as 'Valid' when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Valid'
        end

        it "should queue a raise authentication valid event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_valid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems verify_credentials successful" do
        before(:each) do
          @ems.stub(:verify_credentials).and_return(true)
        end

        it "should return true when calling authentication_check" do
          @ems.authentication_check.should be_true
        end

        it "should set the ems's authentication as 'Valid' when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Valid'
        end

        it "should queue a raise authentication valid event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_valid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with host verify_credentials raising a known 'Unreachable' error" do
        before(:each) do
          @host.stub(:verify_credentials).and_raise(MiqException::MiqUnreachableError)
        end

        it "should return false when calling host authentication_check" do
          @host.authentication_check.should_not be_true
        end

        it "should set the host's authentication as 'Unreachable' when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Unreachable'
        end

        it "should queue a raise host authentication unreachable event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_unreachable', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems verify_credentials raising a known 'Unreachable' error" do
        before(:each) do
          @ems.stub(:verify_credentials).and_raise(MiqException::MiqUnreachableError)
        end

        it "should return false when calling ems authentication_check" do
          @ems.authentication_check.should_not be_true
        end

        it "should set the ems's authentication as 'Unreachable' when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Unreachable'
        end

        it "should queue a raise ems authentication unreachable event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_unreachable', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with host verify_credentials raising invalid credentials" do
        before(:each) do
          @host.stub(:verify_credentials).and_raise(MiqException::MiqInvalidCredentialsError)
        end

        it "should return false when calling host authentication_check" do
          @host.authentication_check.should_not be_true
        end

        it "should set the host's authentication as :error when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Invalid'
        end

        it "should queue a raise host authentication error event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_invalid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems verify_credentials raising invalid credentials" do
        before(:each) do
          @ems.stub(:verify_credentials).and_raise(MiqException::MiqInvalidCredentialsError)
        end

        it "should return false when calling authentication_check" do
          @ems.authentication_check.should_not be_true
        end

        it "should set the ems's authentication as :error when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Invalid'
        end

        it "should queue a raise ems authentication error event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_invalid', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with host verify_credentials raising an unexpected error" do
        before(:each) do
          @host.stub(:verify_credentials).and_raise(RuntimeError)
        end

        it "should return false when calling host authentication_check" do
          @host.authentication_check.should_not be_true
        end

        it "should set the host's authentication as :error when doing authentication_check" do
          @host.authentication_check
          @host.authentication_best_fit.status.should == 'Error'
        end

        it "should queue a raise host authentication error event when doing authentication_check" do
          @host.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@host.class.name, @host.id], 'host_auth_error', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      context "with ems verify_credentials raising an unexpected error" do
        before(:each) do
          @ems.stub(:verify_credentials).and_raise(RuntimeError)
        end

        it "should return false when calling authentication_check" do
          @ems.authentication_check.should_not be_true
        end

        it "should set the ems's authentication as :error when doing authentication_check" do
          @ems.authentication_check
          @ems.authentication_best_fit.status.should == 'Error'
        end

        it "should queue a raise ems authentication error event when doing authentication_check" do
          @ems.authentication_check
          events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
          args = [ [@ems.class.name, @ems.id], 'ems_auth_error', {}]
          events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
        end
      end

      it "should return nothing if update_authentication is passed no data" do
        @ems.update_authentication({}).should be_nil
      end

      it "should have new user/password to apply" do
        @orig_ems_user.should_not equal @data[:default][:userid]
        @orig_ems_pwd.should_not equal @data[:default][:password]
      end

      it "should have existing user/pass matching cached one" do
        @ems.auth_user_pwd(:default).should == [@orig_ems_user, @orig_ems_pwd]
      end

      it "should NOT change credentials if save false" do
        @ems.update_authentication(@data, :save => false)
        @ems.reload.auth_user_pwd(:default).should == [@orig_ems_user, @orig_ems_pwd]
      end

      it "should change credentials if save nil" do
        @ems.update_authentication(@data)
        @ems.auth_user_pwd(:default).should == [@data[:default][:userid], @data[:default][:password]]
      end

      it "should change credentials if save true" do
        @ems.update_authentication(@data, :save => true)
        @ems.auth_user_pwd(:default).should == [@data[:default][:userid], @data[:default][:password]]
      end

      it "should NOT call after_authentication_changed when calling update_authentication with save false" do
        Authentication.any_instance.should_receive(:after_authentication_changed).never
        @ems.update_authentication(@data, :save => false)
      end

      it "should call after_authentication_changed when calling update_authentication with save nil" do
        Authentication.any_instance.should_receive(:after_authentication_changed)
        @ems.update_authentication(@data)
      end

      it "should call after_authentication_changed when calling update_authentication with save true" do
        Authentication.any_instance.should_receive(:after_authentication_changed)
        @ems.update_authentication(@data, :save => true)
      end

      it "should queue a raise authentication change event when calling update_authentication" do
        @ems.update_authentication(@data, :save => true)
        events = MiqQueue.find(:all, :conditions => {:class_name => "MiqEvent", :method_name => "raise_evm_event" })
        args = [ [@ems.class.name, @ems.id], 'ems_auth_changed', {}]
        events.any? {|e| e.args == args }.should be_true, "#{events.inspect} with args: #{args.inspect} expected"
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
          after.should > @before
        end

        it "should update credentials_changed_on when changing userid/password and saving" do
          @auth.update_attribute(:userid, 'blah')
          after = @auth.credentials_changed_on
          after.should > @before
        end
      end

      context "with saved authentications" do
        before(:each) do
          @ems.update_authentication(@data, :save => true)
          @conditions = {:class_name => @ems.class.base_class.name, :instance_id => @ems.id, :method_name => 'authentication_check_types', :role => @ems.authentication_check_role}
          @queued_auth_checks = MiqQueue.find(:all, :conditions => @conditions)
        end

        it "should queue validation of authentication" do
          @queued_auth_checks.length.should == 1
        end

        it "should queue only 1 auth validation per ci" do
          @ems.authentication_check_types_queue(:default)
          @ems.authentication_check_types_queue(:default)
          MiqQueue.count(:conditions => @conditions).should == 1
        end

        it "should call authentication_check when processing the validation check" do
          EmsVmware.any_instance.should_receive(:authentication_check)
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
          @ems.auth_user_pwd(:default).should == [@orig_ems_user, @orig_ems_pwd]
        end

        it "should not call after_authentication_changed" do
          Authentication.any_instance.should_receive(:after_authentication_changed).never
          Authentication.any_instance.should_receive(:set_credentials_changed_on).never
          @ems.update_authentication(@data, :save => true)
        end

        it "should not delete" do
          @ems.update_authentication(@data, :save => true)
          @ems.authentications.length.should == 1
        end
      end

      context "creds incomplete userid" do
        before(:each) do
          @data[:default][:userid] = nil
          @data[:default][:password] = @orig_ems_pwd
        end

        it "should not delete if save false" do
          @ems.update_authentication(@data, :save => false)
          @ems.auth_user_pwd(:default).should == [@orig_ems_user, @orig_ems_pwd]
        end

        it "should not call after_authentication_changed" do
          Authentication.any_instance.should_receive(:after_authentication_changed).never
          Authentication.any_instance.should_receive(:set_credentials_changed_on).never
          @ems.update_authentication(@data, :save => true)
        end

        it "should delete" do
          @ems.update_authentication(@data, :save => true)
          @ems.has_authentication_type?(:default).should_not be_true
        end
      end

      context "userid blanked out" do
        before do
          @data[:default][:userid] = ""
          @data[:default][:password] = "abc"
        end

        it "deletes the record if userid is blank" do
          @host.update_authentication(@data, :save => true)
          @host.auth_user_pwd(:default).should == nil
          @host.has_authentication_type?(:default).should_not be_true
        end
      end

      context "password blanked out" do
        before do
          @data[:default][:userid] = @orig_ems_user
          @data[:default][:password] = ""
        end

        it "sets the password to ''" do
          @host.update_authentication(@data, :save => true)
          @host.has_authentication_type?(:default).should be_true
          @host.auth_user_pwd(:default).should == [@orig_ems_user, '']
        end
      end
    end
  end
end
