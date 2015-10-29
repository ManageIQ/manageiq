require "spec_helper"
include UiConstants

describe OpsController do
  render_views

  context "::Tenants" do
    before do
      Tenant.seed
      MiqRegion.seed
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
      it "renders quota usage table for tenant" do
        tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
        tenant.set_quotas(:cpu_allocated => {:value => 1024},
                          :vms_allocated => {:value => 27},
                          :mem_allocated => {:value => 4096 * GIGABYTE})

        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :id => "tn-#{controller.to_cid(tenant.id)}", :format => :js

        response.should render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
        expect(response.body).to include('Tenant Quota')
        expect(response.body).to include('<th>\nName\n<\/th>\n<th>\nTotal Quota\n<\/th>\n<th>\nIn Use\n' \
                                         '<\/th>\n<th>\nAllocated\n<\/th>\n<th>\nAvailable\n<\/th>')
        expect(response.body).to include('4096.0 GB')
        expect(response.body).to include('1024 Count')
        expect(response.body).to include('27 Count')
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
      before do
        @tenant = Tenant.seed
        server = EvmSpecHelper.local_miq_server
        MiqServer.stub(:my_server).and_return(server)
      end

      it "saves name in record when use_config_attributes is false" do
        controller.instance_variable_set(:@_params,
                                         :divisible                 => true,
                                         :use_config_for_attributes => "on"
                                        )
        controller.send(:tenant_set_record_vars, @tenant)
        stub_server_configuration(:server => { :company => "Settings Company Name"})
        expect(@tenant.name).to eq "Settings Company Name"
      end

      it "does not save name in record when use_config_for_attributes is true" do
        controller.instance_variable_set(:@_params,
                                         :name      => "Foo_Bar",
                                         :divisible => true
                                        )
        @tenant.update_attributes(:use_config_for_attributes => false)
        @tenant.reload
        controller.send(:tenant_set_record_vars, @tenant)
        @tenant.name.should eq("Foo_Bar")
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
                                         :name      => "Foo_Bar",
                                         :divisible => "False",
                                         :parent    => "some_parent"
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
                                         :name      => "OneTenant",
                                         :quotas    => {
                                           :cpu_allocated => {:value => 1024.0},
                                           :mem_allocated => {:value => 4096.0}
                                         },
                                         :id        => @tenant.id,
                                         :button    => "save",
                                         :divisible => "true")
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        flash_message[:message].should include("Quotas for Tenant \"OneTenant\" were saved")
        flash_message[:level].should be(:success)
      end
    end

    describe "#tags_edit" do
      before(:each) do
        user = FactoryGirl.create(:user)
        set_user_privileges user
        @tenant = FactoryGirl.create(:tenant,
                                     :name      => "OneTenant",
                                     :parent    => Tenant.root_tenant,
                                     :domain    => "test",
                                     :subdomain => "test")
        sb_hash = { :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(@tenant.id)}"}},
                    :active_tree => :rbac_tree,
                    :active_tab  => "rbac_details"
                  }
        controller.instance_variable_set(:@sb, sb_hash)
        ApplicationHelper.stub(:role_allows).and_return(true)
        @tenant.stub(:tagged_with).with(:cat => user.userid).and_return("my tags")
        classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
        @tag1 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag1",
                                   :parent => classification
                                  )
        @tag2 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag2",
                                   :parent => classification
                                  )
        Classification.stub(:find_assigned_entries).with(@tenant).and_return([@tag1, @tag2])
        controller.instance_variable_set(:@sb,
                                         :trees       => {:rbac_tree => {:active_node => "root"}},
                                         :active_tree => :rbac_tree)
        controller.stub(:get_node_info)
        controller.stub(:replace_right_cell)
        session[:tag_db] = "Tenant"
        edit = { :key        => "Tenant_edit_tags__#{@tenant.id}",
                 :tagging    => "Tenant",
                 :object_ids => [@tenant.id],
                 :current    => {:assignments => []},
                 :new        => {:assignments => [@tag1.id, @tag2.id]}
               }
        session[:edit] = edit
      end

      after(:each) do
        expect(response.status).to eq(200)
      end

      it "builds tagging screen" do
        EvmSpecHelper.create_guid_miq_server_zone

        controller.instance_variable_set(:@sb, :action => "rbac_tenant_tags_edit")
        controller.instance_variable_set(:@_params, :miq_grid_checks => @tenant.id.to_s)
        controller.send(:rbac_tenant_tags_edit)
        assigns(:flash_array).should be_nil
        assigns(:entries).should_not be_nil
      end

      it "cancels tags edit" do
        controller.instance_variable_set(:@_params, :button => "cancel", :id => @tenant.id)
        controller.send(:rbac_tenant_tags_edit)
        assigns(:flash_array).first[:message].should include("was cancelled")
        assigns(:edit).should be_nil
      end

      it "save tags" do
        controller.instance_variable_set(:@_params, :button => "save", :id => @tenant.id)
        controller.send(:rbac_tenant_tags_edit)
        assigns(:flash_array).first[:message].should include("Tag edits were successfully saved")
        assigns(:edit).should be_nil
      end
    end
  end

  context "::MiqGroup" do
    before do
      MiqGroup.seed
      MiqRegion.seed
      set_user_privileges
    end

    it "does not display tenant default groups in Edit Sequence" do
      tg = FactoryGirl.create(:tenant).default_miq_group
      g  = FactoryGirl.create(:miq_group)

      expect(MiqGroup.tenant_groups).to include(tg)
      expect(MiqGroup.tenant_groups).not_to include(g)
      session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
      controller.stub(:replace_right_cell)
      controller.send(:rbac_group_seq_edit)
      expect(response.status).to eq(200)
      edit = controller.instance_variable_get(:@edit)
      expect(edit[:current][:ldap_groups].find { |lg| lg.group_type == 'tenant' }).to be(nil)
      expect(edit[:current][:ldap_groups].find { |lg| lg.group_type == 'user' }).not_to be(nil)
    end
  end
end
