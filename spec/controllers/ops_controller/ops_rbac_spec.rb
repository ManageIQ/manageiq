describe OpsController do
  render_views

  context "::Tenants" do
    before do
      Tenant.seed
      MiqRegion.seed
      stub_user(:features => :all)
    end

    context "#tree_select" do
      it "renders rbac_details tab when rbac_tree root node is selected" do
        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :params => { :id => 'root', :format => :js }

        expect(response).to render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
      end

      it "renders tenants partial when tenant node is selected" do
        tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)

        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :params => { :id => "tn-#{controller.to_cid(tenant.id)}", :format => :js }

        expect(response).to render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
      end

      it "does not display tenant groups in the details paged" do
        tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)

        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :params => { :id => "tn-#{controller.to_cid(tenant.id)}", :format => :js }

        expect(response).to render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)
        expect(response.body).not_to include('View this Group')
      end

      it "renders quota usage table for tenant" do
        tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
        tenant.set_quotas(:cpu_allocated => {:value => 1024},
                          :vms_allocated => {:value => 27},
                          :mem_allocated => {:value => 4096 * GIGABYTE})

        session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
        post :tree_select, :params => { :id => "tn-#{controller.to_cid(tenant.id)}", :format => :js }

        expect(response).to render_template('ops/_rbac_details_tab')
        expect(response.status).to eq(200)

        tab_content = JSON.parse(response.body)['replacePartials']['ops_tabs']
        expect(tab_content).to include('Tenant Quota')
        expect(tab_content).to include("<th>\nName\n<\/th>\n<th>\nTotal Quota\n<\/th>\n<th>\nIn Use\n" \
                                         "<\/th>\n<th>\nAllocated\n<\/th>\n<th>\nAvailable\n<\/th>")
        expect(tab_content).to include('4096.0 GB')
        expect(tab_content).to include('1024 Count')
        expect(tab_content).to include('27 Count')
      end
    end

    context "#rbac_tenant_get_details" do
      it "sets @tenant record" do
        t = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant, :subdomain => "foo")
        controller.send(:rbac_tenant_get_details, t.id)
        expect(assigns(:tenant)).to eq(t)
      end
    end

    context "#rbac_tenant_delete" do
      before do
        allow(ApplicationHelper).to receive(:role_allows?).and_return(true)
        @t = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(@t.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        controller.instance_variable_set(:@_params, :id => @t.id)
        expect(controller).to receive(:render)
      end

      it "deletes a tenant record successfully" do
        expect(controller).to receive(:x_active_tree_replace_cell)
        controller.send(:rbac_tenant_delete)

        expect(response.status).to eq(200)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Delete successful")
        expect(flash_message[:level]).to be(:success)
      end

      it "returns error flash when tenant cannot be deleted" do
        FactoryGirl.create(:miq_group, :tenant => @t)
        controller.send(:rbac_tenant_delete)

        expect(response.status).to eq(200)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Error during delete")
        expect(flash_message[:level]).to be(:error)
      end

      it "deletes checked tenant records successfully" do
        allow(ApplicationHelper).to receive(:role_allows?).and_return(true)
        t = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
        sb_hash = {
          :trees       => {:rbac_tree => {:active_node => "tn-#{controller.to_cid(t.id)}"}},
          :active_tree => :rbac_tree,
          :active_tab  => "rbac_details"
        }
        controller.instance_variable_set(:@sb, sb_hash)
        allow(controller).to receive(:find_checked_items).and_return([t.id])
        expect(controller).to receive(:x_active_tree_replace_cell)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_delete)

        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Delete successful")
        expect(flash_message[:level]).to be(:success)
      end
    end

    context "#rbac_tenants_list" do
      it "gets the list of tenants" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@settings, {})
        expect(response.status).to eq(200)
        controller.send(:rbac_tenants_list)
        expect(assigns(:view)).not_to be_nil
        expect(assigns(:pages)).not_to be_nil
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
        allow(ApplicationHelper).to receive(:role_allows?).and_return(true)
      end
      it "resets tenant edit" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "reset")
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("All changes have been reset")
        expect(flash_message[:level]).to be(:warning)
      end

      it "cancels tenant edit" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "cancel", :divisible => "true")
        expect(controller).to receive(:x_active_tree_replace_cell)
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Edit of Tenant \"#{@tenant.name}\" was cancelled by the user")
        expect(flash_message[:level]).to be(:success)
      end

      it "saves tenant record changes" do
        controller.instance_variable_set(:@_params,
                                         :name        => "Foo_Bar",
                                         :description => "Foo Bar Description",
                                         :id          => @tenant.id,
                                         :button      => "save",
                                         :divisible   => "true")
        expect(controller).to receive(:x_active_tree_replace_cell)
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_edit)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Tenant \"Foo_Bar\" was saved")
        expect(flash_message[:level]).to be(:success)
      end
    end

    context "#tenant_set_record_vars" do
      before do
        @tenant = Tenant.seed
        server = EvmSpecHelper.local_miq_server
        allow(MiqServer).to receive(:my_server).and_return(server)
      end

      it "saves name in record when use_config_attributes is true" do
        controller.instance_variable_set(:@_params,
                                         :divisible                 => true,
                                         :use_config_for_attributes => "on"
                                        )
        controller.send(:tenant_set_record_vars, @tenant)
        stub_settings(:server => {:company => "Settings Company Name"})
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
        expect(@tenant.name).to eq("Foo_Bar")
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
        expect(@tenant.divisible).to be_truthy
        expect(@tenant.parent.id).to eq(Tenant.root_tenant.id)
        expect(@tenant.name).to eq("Foo_Bar")
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
        expect(tenant.divisible).to be_falsey
        expect(tenant.parent.id).to eq(@tenant.id)
        expect(tenant.name).to eq("Foo_Bar")
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
        allow(ApplicationHelper).to receive(:role_allows?).and_return(true)
      end
      it "resets tenant manage quotas" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "reset")
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("All changes have been reset")
        expect(flash_message[:level]).to be(:warning)
      end

      it "cancels tenant manage quotas" do
        controller.instance_variable_set(:@_params, :id => @tenant.id, :button => "cancel", :divisible => "true")
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message])
          .to include("Manage quotas for Tenant \"#{@tenant.name}\" was cancelled by the user")
        expect(flash_message[:level]).to be(:success)
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
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:rbac_tenant_manage_quotas)
        flash_message = assigns(:flash_array).first
        expect(flash_message[:message]).to include("Quotas for Tenant \"OneTenant\" were saved")
        expect(flash_message[:level]).to be(:success)
      end
    end

    describe "#tags_edit" do
      let!(:user) { stub_user(:features => :all) }
      before(:each) do
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
        allow(ApplicationHelper).to receive(:role_allows?).and_return(true)
        allow(@tenant).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
        classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
        @tag1 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag1",
                                   :parent => classification
                                  )
        @tag2 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag2",
                                   :parent => classification
                                  )
        allow(Classification).to receive(:find_assigned_entries).with(@tenant).and_return([@tag1, @tag2])
        controller.instance_variable_set(:@sb,
                                         :trees       => {:rbac_tree => {:active_node => "root"}},
                                         :active_tree => :rbac_tree)
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)
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
        expect(assigns(:flash_array)).to be_nil
        expect(assigns(:entries)).not_to be_nil
      end

      it "cancels tags edit" do
        controller.instance_variable_set(:@_params, :button => "cancel", :id => @tenant.id)
        controller.send(:rbac_tenant_tags_edit)
        expect(assigns(:flash_array).first[:message]).to include("was cancelled")
        expect(assigns(:edit)).to be_nil
      end

      it "save tags" do
        controller.instance_variable_set(:@_params, :button => "save", :id => @tenant.id)
        controller.send(:rbac_tenant_tags_edit)
        expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
        expect(assigns(:edit)).to be_nil
      end
    end
  end

  context "::MiqGroup" do
    before do
      MiqUserRole.seed
      MiqGroup.seed
      MiqRegion.seed
      stub_user(:features => :all)
    end

    it "does not display tenant default groups in Edit Sequence" do
      tg = FactoryGirl.create(:tenant).default_miq_group
      g  = FactoryGirl.create(:miq_group)

      expect(MiqGroup.tenant_groups).to include(tg)
      expect(MiqGroup.tenant_groups).not_to include(g)
      session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
      allow(controller).to receive(:replace_right_cell)
      controller.send(:rbac_group_seq_edit)
      expect(response.status).to eq(200)
      edit = controller.instance_variable_get(:@edit)
      expect(edit[:current][:ldap_groups].find { |lg| lg.group_type == 'tenant' }).to be(nil)
      expect(edit[:current][:ldap_groups].find { |lg| lg.group_type == 'user' }).not_to be(nil)
    end
  end

  context "rbac_role_edit" do
    before do
      MiqUserRole.seed
      MiqGroup.seed
      MiqRegion.seed
      stub_user(:features => :all)
    end

    it "creates a new user role successfully" do
      allow(controller).to receive(:replace_right_cell)
      controller.instance_variable_set(:@_params, :button => "add")
      new = {:features => ["everything"], :name => "foo"}
      edit = {:key     => "rbac_role_edit__new",
              :new     => new,
              :current => new
      }
      session[:edit] = edit
      controller.send(:rbac_role_edit)
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("Role \"foo\" was saved")
      expect(controller.send(:flash_errors?)).to be_falsey
    end
  end

  render_views

  context "::MiqRegion" do
    before do
      EvmSpecHelper.local_miq_server
      root_tenant = Tenant.seed
      MiqUserRole.seed
      MiqGroup.seed
      MiqRegion.seed
      role = MiqUserRole.find_by_name("EvmRole-SuperAdministrator")
      @t1 = FactoryGirl.create(:tenant, :name => "ten1", :parent => root_tenant)
      @g1 = FactoryGirl.create(:miq_group, :description => 'group1', :tenant => @t1, :miq_user_role => role)
      @u1 = FactoryGirl.create(:user, :miq_groups => [@g1])
      @t2 = FactoryGirl.create(:tenant, :name => "ten2", :parent => root_tenant)
      @g2a  = FactoryGirl.create(:miq_group, :description => 'gr2a', :tenant => @t2, :miq_user_role => role)
      @g2b  = FactoryGirl.create(:miq_group, :description => 'gr2b1', :tenant => @t2, :miq_user_role => role)
      @u2a = FactoryGirl.create(:user, :miq_groups => [@g2a])
      @u2a2 = FactoryGirl.create(:user, :miq_groups => [@g2a])
      @u2b = FactoryGirl.create(:user, :miq_groups => [@g2b])
      @u2b2 = FactoryGirl.create(:user, :miq_groups => [@g2b])
      @u2b3 = FactoryGirl.create(:user, :miq_groups => [@g2b])
      session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
      allow(controller).to receive(:replace_right_cell)
    end

    it "displays the access object count for the current tenant" do
      login_as @u1
      session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
      allow(controller).to receive(:replace_right_cell)
      post :tree_select, :params => { :id => 'root', :format => :js }
      expect(controller.instance_variable_get(:@groups_count)).to eq(1)
      expect(controller.instance_variable_get(:@tenants_count)).to eq(1)
      expect(controller.instance_variable_get(:@users_count)).to eq(1)
    end

    it "displays the access object count for the current tenant" do
      login_as @u2a
      session[:sandboxes] = {"ops" => {:active_tree => :rbac_tree}}
      allow(controller).to receive(:replace_right_cell)
      post :tree_select, :params => { :id => 'root', :format => :js }
      expect(controller.instance_variable_get(:@groups_count)).to eq(2)
      expect(controller.instance_variable_get(:@tenants_count)).to eq(1)
      expect(controller.instance_variable_get(:@users_count)).to eq(5)
    end
  end
end
