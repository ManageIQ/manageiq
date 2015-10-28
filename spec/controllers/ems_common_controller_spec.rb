require "spec_helper"

describe EmsCloudController do
  context "::EmsCommon" do
    context "#get_form_vars" do
      it "check if the default port for openstack/openstack_infra/rhevm is set" do
        controller.instance_variable_set(:@edit, :new => {})
        controller.instance_variable_set(:@_params, :server_emstype => "openstack")
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should == 5000

        controller.instance_variable_set(:@_params, {:server_emstype => "openstack_infra"})
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should == 5000

        controller.instance_variable_set(:@_params, :server_emstype => "ec2")
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should.nil?
      end
    end

    context "#get_form_vars" do
      it "check if provider_region gets reset when provider type is changed on add screen" do
        controller.instance_variable_set(:@edit, :new => {})
        controller.instance_variable_set(:@_params, :server_emstype => "ec2")
        controller.instance_variable_set(:@_params, :provider_region => "some_region")

        controller.send(:get_form_vars)
        assigns(:edit)[:new][:provider_region].should == "some_region"

        controller.instance_variable_set(:@_params, :server_emstype => "openstack")
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:provider_region].should be_nil
      end
    end

    context "#form_field_changed" do
      before :each do
        set_user_privileges
      end

      it "form_div should be updated when server type is sent up" do
        controller.instance_variable_set(:@edit, :new => {}, :key => "ems_edit__new")
        session[:edit] = assigns(:edit)
        post :form_field_changed, :server_emstype => "rhevm", :id => "new"
        response.body.should include("form_div")
      end

      it "form_div should not be updated when other fields are sent up" do
        controller.instance_variable_set(:@edit, :new => {}, :key => "ems_edit__new")
        session[:edit] = assigns(:edit)
        post :form_field_changed, :name => "Test", :id => "new"
        response.body.should_not include("form_div")
      end
    end

    context "#set_record_vars" do
      context "strip leading/trailing whitespace from hostname/ipaddress" do
        after :each do
          set_user_privileges
          controller.instance_variable_set(:@edit, :new => {:name     => 'EMS 1',
                                                            :emstype  => @type,
                                                            :hostname => '  10.10.10.10  ',
                                                            :port     => '5000'},
                                                   :key => 'ems_edit__new')
          session[:edit] = assigns(:edit)
          controller.send(:set_record_vars, @ems)
          expect(@ems.hostname).to eq('10.10.10.10')
        end

        it "when adding cloud EMS" do
          @type = 'openstack'
          @ems  = ManageIQ::Providers::Openstack::CloudManager.new
        end

        it "when adding infra EMS" do
          @type = 'rhevm'
          @ems  = ManageIQ::Providers::Redhat::InfraManager.new
        end
      end
    end

    context "#update_button_validate" do
      context "when authentication_check" do
        let(:mocked_ems_cloud) { mock_model(EmsCloud) }
        before(:each) do
          controller.instance_variable_set(:@_params, :id => "42", :type => "amqp")
          controller.should_receive(:find_by_id_filtered).with(EmsCloud, "42").and_return(mocked_ems_cloud)
          controller.should_receive(:set_record_vars).with(mocked_ems_cloud, :validate).and_return(mocked_ems_cloud)
        end

        it "successful flash message (unchanged)" do
          controller.stub(:edit_changed? => false)
          mocked_ems_cloud.should_receive(:authentication_check).with("amqp", :save => true).and_return([true, ""])
          controller.should_receive(:add_flash).with(_("Credential validation was successful"))
          controller.should_receive(:render_flash)
          controller.send(:update_button_validate)
        end

        it "unsuccessful flash message (changed)" do
          controller.stub(:edit_changed? => true)
          mocked_ems_cloud.should_receive(:authentication_check).with("amqp", :save => false).and_return([false, "Invalid"])
          controller.should_receive(:add_flash).with(_("Credential validation was not successful: Invalid"), :error)
          controller.should_receive(:render_flash)
          controller.send(:update_button_validate)
        end
      end
    end
  end
end

describe EmsContainerController do
  context "::EmsCommon" do
    context "#update" do
      it "updates provider with new token" do
        MiqServer.stub(:my_zone).and_return("default")
        set_user_privileges
        @ems = ManageIQ::Providers::Kubernetes::ContainerManager.create(:name => "k8s", :hostname => "10.10.10.1", :port => 5000)
        controller.instance_variable_set(:@edit,
                                         :new    => {:name         => @ems.name,
                                                     :emstype      => @ems.type,
                                                     :hostname     => @ems.hostname,
                                                     :port         => @ems.port,
                                                     :bearer_token => 'valid-token'},
                                         :key    => "ems_edit__#{@ems.id}",
                                         :ems_id => @ems.id)
        session[:edit] = assigns(:edit)
        post :update, :button => "save", :id => @ems.id, :type => @ems.type
        response.status.should == 200
        ManageIQ::Providers::Kubernetes::ContainerManager.last.authentication_token("bearer").should == "valid-token"
      end
    end

    context "#button" do
      before(:each) do
        set_user_privileges
        FactoryGirl.create(:vmdb_database)
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "when VM Migrate is pressed for unsupported type" do
        controller.stub(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_microsoft)
        post :button, :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => "1"
        controller.send(:flash_errors?).should be_true
        assigns(:flash_array).first[:message].should include('does not apply')
      end

      it "when VM Migrate is pressed for supported type" do
        controller.stub(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_vmware)
        post :button, :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => "1"
        controller.send(:flash_errors?).should_not be_true
      end

      it "when VM Migrate is pressed for supported type" do
        controller.stub(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_vmware)
        post :button, :pressed => "vm_edit", :format => :js, "check_#{vm.id}" => "1"
        controller.send(:flash_errors?).should_not be_true
      end
    end
  end
end

describe EmsInfraController do
  context "#show_link" do
    let(:ems) { mock_model(EmsInfra) }
    it "sets relative url" do
      controller.instance_variable_set(:@table_name, "ems_infra")
      link = controller.send(:show_link, ems, :display => "vms")
      link.should eq("/ems_infra/show/#{ems.id}?display=vms")
    end

    context "#restore_password" do
      it "populates the password from the ems record if params[:restore_password] exists" do
        infra_ems = EmsInfra.new
        infra_ems.stub(:authentication_password).and_return("default_password")
        edit = {:ems_id => infra_ems.id, :new => {}}
        controller.instance_variable_set(:@edit, edit)
        controller.instance_variable_set(:@ems, infra_ems)
        controller.instance_variable_set(:@_params,
                                         :restore_password => true,
                                         :default_password => "[FILTERED]",
                                         :default_verify   => "[FILTERED]")
        controller.send(:restore_password)
        assigns(:edit)[:new][:default_password].should == infra_ems.authentication_password
      end
    end
  end
end
