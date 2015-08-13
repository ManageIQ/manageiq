require "spec_helper"

describe EmsCloudController do
  context "::EmsCommon" do
    context "#get_form_vars" do
      it "check if the default port for openstack/openstack_infra/rhevm is set" do
        controller.instance_variable_set(:@edit, {:new => {}})
        controller.instance_variable_set(:@_params, {:server_emstype => "openstack"})
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should == 5000

        controller.instance_variable_set(:@_params, {:server_emstype => "openstack_infra"})
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should == 5000

        controller.instance_variable_set(:@_params, {:server_emstype => "ec2"})
        controller.send(:get_form_vars)
        assigns(:edit)[:new][:port].should == nil
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
        controller.instance_variable_set(:@edit, {:new => {}, :key => "ems_edit__new"})
        session[:edit] = assigns(:edit)
        post :form_field_changed, :server_emstype => "rhevm", :id => "new"
        response.body.should include("form_div")
      end

      it "form_div should not be updated when other fields are sent up" do
        controller.instance_variable_set(:@edit, {:new => {}, :key => "ems_edit__new"})
        session[:edit] = assigns(:edit)
        post :form_field_changed, :name => "Test", :id => "new"
        response.body.should_not include("form_div")
      end
    end

    context "#create" do
      it "displays correct attribute name in error message when adding cloud EMS" do
        set_user_privileges
        controller.instance_variable_set(:@edit, {:new => {:name => "EMS 1", :emstype => "ec2"},
                                                  :key => "ems_edit__new"})
        session[:edit] = assigns(:edit)
        controller.stub(:drop_breadcrumb)
        post :create, :button => "add"
        flash_messages = assigns(:flash_array)
        flash_messages.first[:message].should include("Region is not included in the list")
        flash_messages.first[:level].should == :error
      end

      it "displays correct attribute name in error message when adding infra EMS" do
        set_user_privileges
        controller.instance_variable_set(:@edit, {:new => {:name => "EMS 2", :emstype => "rhevm"},
                                                  :key => "ems_edit__new"})
        session[:edit] = assigns(:edit)
        controller.stub(:drop_breadcrumb)
        post :create, :button => "add"
        flash_messages = assigns(:flash_array)
        flash_messages.first[:message].should include("Host Name can't be blank")
        flash_messages.first[:level].should == :error
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
        set_user_privileges
        @ems = EmsKubernetes.create(:name => "k8s", :hostname => "10.10.10.1", :port => 5000)
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
        EmsKubernetes.last.authentication_token("bearer").should == "valid-token"
      end
    end
  end
end
