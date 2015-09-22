require "spec_helper"
include UiConstants

describe OpsController do
  render_views

  context "::Tenants" do
    before do
      EvmSpecHelper.create_root_tenant
      set_user_privileges
    end

    context "#tree_select" do
      it "renders rbac_details tab when rbac_tree root node is selected" do
        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :id => 'root', :format => :js

        response.should render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
      end

      it "renders tenants partial when tenant node is selected" do
        tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)

        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :id => "tn-#{controller.to_cid(tenant.id)}", :format => :js

        response.should render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
      end
    end

    context "#rbac_tenant_get_details" do
      it "sets @tenant record" do
        t = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant, :subdomain => "foo")
        controller.send(:rbac_tenant_get_details, t.id)
        assigns(:tenant).should eq(t)
      end
    end

    context "#rbac_tenant_delete" do
      it "deletes a tenant record successfully" do
        ApplicationHelper.stub(:role_allows).and_return(true)
        t = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(t.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        controller.instance_variable_set(:@_params, :id => t.id)
        controller.should_receive(:x_active_tree_replace_cell)
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_delete)

        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Delete successful")
        flash_message[:level].should be(:success)
      end
    end

    context "#rbac_tenants_list" do
      it "gets the list of tenants" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@settings, {})
        expect(response.status).to eq(200)
        controller.send(:rbac_tenants_list)
        assigns(:view).should_not be_nil
        assigns(:pages).should_not be_nil
      end
    end

    context "#rbac_tenant_edit" do
      before do
        @tenant = FactoryGirl.create(:tenant,
                                     :name      => "Foo",
                                     :parent    => Tenant.root_tenant,
                                     :subdomain => "test")
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(@tenant.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        ApplicationHelper.stub(:role_allows).and_return(true)
      end
      it "resets tenant edit" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "reset")
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("All changes have been reset")
        flash_message[:level].should be(:warning)
      end

      it "cancels tenant edit" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "cancel", :divisible => "true")
        controller.should_receive(:x_active_tree_replace_cell)
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Edit of Tenant \"#{@tenant.name}\" was cancelled by the user")
        flash_message[:level].should be(:success)
      end

      it "saves tenant record changes" do
        controller.instance_variable_set(:@_params,
                                         :name        => "Foo_Bar",
                                         :description => "Foo Bar Description",
                                         :id          => @tenant.id,
                                         :button      => "save",
                                         :divisible   => "true")
        controller.should_receive(:x_active_tree_replace_cell)
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Tenant \"Foo_Bar\" was saved")
        flash_message[:level].should be(:success)
      end
    end

    context "#tenant_set_record_vars" do
      before :each do
        @tenant = FactoryGirl.create(:tenant,
                                    :name        => "Foo",
                                    :description => "Foo Description",
                                    :divisible   => 1,
                                    :parent      => Tenant.root_tenant)
        controller.instance_variable_set(:@_params,
                                         :name        => "Foo_Bar",
                                         :divisible   => "False",
                                         :parent      => "some_parent"
        )
      end

      it "does not change value of parent & divisible fields for existing record" do
        controller.send(:tenant_set_record_vars, @tenant)
        @tenant.divisible.should be_true
        @tenant.parent.id.should eq(Tenant.root_tenant.id)
        @tenant.name.should eq("Foo_Bar")
      end

      it "sets value of parent & divisible fields for new record" do
        tenant = FactoryGirl.build(:tenant, :parent => Tenant.root_tenant)
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(@tenant.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        controller.send(:tenant_set_record_vars, tenant)
        tenant.divisible.should be_false
        tenant.parent.id.should eq(@tenant.id)
        tenant.name.should eq("Foo_Bar")
      end
    end

    context "#rbac_tenant_manage_quotas" do
      before do
        @tenant = FactoryGirl.create(:tenant,
                                     :name      => "OneTenant",
                                     :parent    => Tenant.root_tenant,
                                     :domain    => "test",
                                     :subdomain => "test")
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(@tenant.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        ApplicationHelper.stub(:role_allows).and_return(true)
      end
      it "resets tenant manage quotas" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "reset")
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("All changes have been reset")
        flash_message[:level].should be(:warning)
      end

      it "cancels tenant manage quotas" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "cancel", :divisible => "true")
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Manage quotas for Tenant \"#{@tenant.name}\" was cancelled by the user")
        flash_message[:level].should be(:success)
      end

      it "saves tenant quotas record changes" do
        controller.instance_variable_set(:@_params,
          :name        => "OneTenant",
          :quotas      => {
            :cpu_allocated => {:value => 1024.0},
            :mem_allocated => {:value => 4096.0}
          },
          :id          => @tenant.id,
          :button      => "save",
          :divisible   => "true")
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Quotas for Tenant \"OneTenant\" were saved")
        flash_message[:level].should be(:success)
      end
    end
  end
end
