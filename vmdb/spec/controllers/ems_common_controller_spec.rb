require "spec_helper"

describe EmsCloudController do
  context "::EmsCommon" do
    context "#get_form_vars" do
      it "check if the default port for openstack/openstack_infra/rhevm is set" do
        controller.instance_variable_set(:@model, EmsCloud)
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
        controller.instance_variable_set(:@model, EmsCloud)
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
        controller.instance_variable_set(:@model, EmsCloud)
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

    context "#update_button_validate" do
      context "when verify_credentials" do
        let(:mocked_ems_cloud) { mock_model(EmsCloud) }
        before(:each) do
          controller.instance_variable_set(:@_params, :id => "42", :type => "amqp")
          controller.instance_variable_set(:@model, EmsCloud)
          controller.should_receive(:find_by_id_filtered).with(EmsCloud, "42").and_return(mocked_ems_cloud)
          controller.should_receive(:set_record_vars).with(mocked_ems_cloud, :validate).and_return(mocked_ems_cloud)
        end
        context "returns true" do
          it "renders successful flash message" do
            mocked_ems_cloud.should_receive(:verify_credentials).with("amqp").and_return(true)
            controller.should_receive(:add_flash).with(_("Credential validation was successful"))
            controller.should_receive(:render_flash)
            controller.send(:update_button_validate)
          end
        end
        context "returns false" do
          it "renders unsuccessful flash message" do
            mocked_ems_cloud.should_receive(:verify_credentials).with("amqp").and_return(false)
            controller.should_receive(:add_flash).with(_("Credential validation was not successful"))
            controller.should_receive(:render_flash)
            controller.send(:update_button_validate)
          end
        end
        context "raises StandardError" do
          it "renders error flash message with StandardError" do
            mocked_ems_cloud.should_receive(:verify_credentials).with("amqp").and_raise(StandardError)
            controller.should_receive(:add_flash).with(_("StandardError"), :error)
            controller.should_receive(:render_flash)
            controller.send(:update_button_validate)
          end
        end
      end
    end
  end
end
