describe MiqAeClassController do
  include CompressedIds
  context "#set_record_vars" do
    it "Namespace remains unchanged when a class is edited" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      ns_id = cls.namespace_id
      new = {:name => "New Name", :description => "New Description", :display_name => "Display Name", :inherits => "Some_Class"}
      controller.instance_variable_set(:@sb,
                                       :trees       => {
                                         :ae_tree => {:active_node => "aec-#{cls.id}"}
                                       },
                                       :active_tree => :ae_tree)
      controller.instance_variable_set(:@edit, {:new => new})
      controller.send(:set_record_vars, cls)
      expect(cls.namespace_id).to eq(ns_id)
    end
  end

  context "#set_right_cell_text" do
    it "check if correct namespace_path is being set" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      controller.instance_variable_set(:@sb, {})
      id = "aec-#{cls.id}"
      fq_name = cls.fqname
      controller.send(:set_right_cell_text, id, cls)
      expect(assigns(:sb)[:namespace_path]).to eq(fq_name.gsub!(%r{\/}, " / "))

      id = "root"
      fq_name = ""
      controller.send(:set_right_cell_text, id)
      expect(assigns(:sb)[:namespace_path]).to eq(fq_name)
    end
  end

  context "#domain_lock" do
    it "Marks domain as locked/readonly" do
      stub_user(:features => :all)
      ns = FactoryGirl.create(:miq_ae_domain_enabled)
      controller.instance_variable_set(:@_params, :id => ns.id)
      allow(controller).to receive(:replace_right_cell)
      controller.send(:domain_lock)
      ns.reload
      expect(ns.contents_locked?).to eq(true)
    end
  end

  context "#domain_unlock" do
    it "Marks domain as unlocked/editable" do
      stub_user(:features => :all)
      ns = FactoryGirl.create(:miq_ae_domain_disabled)
      controller.instance_variable_set(:@_params, :id => ns.id)
      allow(controller).to receive(:replace_right_cell)
      controller.send(:domain_unlock)
      ns.reload
      expect(ns.contents_locked?).to eq(false)
    end
  end

  context "#domains_priority_edit" do
    it "sets priority of domains" do
      stub_user(:features => :all)
      FactoryGirl.create(:miq_ae_domain, :name => "test1", :parent => nil, :priority => 1)
      FactoryGirl.create(:miq_ae_domain, :name => "test2", :parent => nil, :priority => 2)
      FactoryGirl.create(:miq_ae_domain, :name => "test3", :parent => nil, :priority => 3)
      FactoryGirl.create(:miq_ae_domain, :name => "test4", :parent => nil, :priority => 4)
      order = %w(test3 test2 test4 test1)
      edit = {
        :new     => {:domain_order => order},
        :key     => "priority__edit",
        :current => {:domain_order => order},
      }
      controller.instance_variable_set(:@_params, :button => "save")
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, {})
      session[:edit] = edit
      allow(controller).to receive(:replace_right_cell)
      controller.send(:domains_priority_edit)
      domain_order = []
      MiqAeDomain.order('priority ASC').collect { |d| domain_order.push(d.name) unless d.priority == 0 }
      expect(domain_order).to eq(edit[:new][:domain_order])
    end
  end

  context "#copy_objects" do
    it "do not replace left side explorer tree when copy form is loaded initially" do
      stub_user(:features => :all)
      d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      node = "aec-#{cls1.id}"
      controller.instance_variable_set(:@sb,
                                       :active_tree => :ae_tree,
                                       :action      => "miq_ae_class_copy",
                                       :trees       => {:ae_tree => {:active_node => node}})
      controller.instance_variable_set(:@_params, :button => "reset", :id => cls1.id)
      allow(controller).to receive(:open_parent_nodes)
      expect(controller).to_not receive(:replace_trees_by_presenter)
      expect(controller).to receive(:render)
      controller.send(:copy_objects)
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "copies class under specified namespace" do
      stub_user(:features => :all)
      d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      d2 = FactoryGirl.create(:miq_ae_domain, :name => "domain2")
      ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => d2.id)

      new = {:domain => d2.id, :namespace => ns2.fqname, :overwrite_location => false}
      selected_items = {cls1.id => cls1.name}
      edit = {
        :new            => new,
        :typ            => MiqAeClass,
        :rec_id         => cls1.id,
        :key            => "copy_objects__#{cls1.id}",
        :current        => new,
        :selected_items => selected_items,
      }
      controller.instance_variable_set(:@_params, :button => "copy", :id => cls1.id)
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, :action => "miq_ae_class_copy")
      session[:edit] = edit
      allow(controller).to receive(:replace_right_cell)
      controller.send(:copy_objects)
      expect(controller.send(:flash_errors?)).not_to be_truthy
      expect(assigns(:flash_array).first[:message]).to include("Copy selected Automate Class was saved")
      expect(MiqAeClass.find_by(:name => cls1.name, :namespace_id => ns2.id)).not_to be_nil
    end

    it "copy class under same namespace returns error when class exists" do
      stub_user(:features => :all)
      d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      new = {:domain => d1.id, :namespace => ns1.fqname, :overwrite_location => false}
      selected_items = {cls1.id => cls1.name}
      edit = {
        :new            => new,
        :typ            => MiqAeClass,
        :rec_id         => cls1.id,
        :key            => "copy_objects__#{cls1.id}",
        :current        => new,
        :selected_items => selected_items,
      }
      controller.instance_variable_set(:@_params, :button => "copy", :id => cls1.id)
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, :action => "miq_ae_class_copy")
      session[:edit] = edit
      allow(controller).to receive(:replace_right_cell)
      expect(controller).to receive(:render)
      controller.send(:copy_objects)
      expect(controller.send(:flash_errors?)).to be_truthy
      expect(assigns(:flash_array).first[:message]).to include("Error during 'Automate Class copy':")
    end

    it "overwrite class under same namespace when class exists" do
      stub_user(:features => :all)
      d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      d2 = FactoryGirl.create(:miq_ae_domain)
      ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => d2.id)

      new = {:domain => d2.id, :namespace => ns2.fqname, :override_existing => true}
      selected_items = {cls1.id => cls1.name}
      edit = {
        :new            => new,
        :typ            => MiqAeClass,
        :rec_id         => cls1.id,
        :key            => "copy_objects__#{cls1.id}",
        :current        => new,
        :selected_items => selected_items,
      }
      controller.instance_variable_set(:@_params, :button => "copy", :id => cls1.id)
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, :action => "miq_ae_class_copy")
      session[:edit] = edit
      allow(controller).to receive(:replace_right_cell)
      controller.send(:copy_objects)
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Copy selected Automate Class was saved")
    end

    it "copies a class with new name under same domain" do
      stub_user(:features => :all)
      d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      new = {:domain => d1.id, :namespace => ns1.fqname, :override_existing => true, :new_name => 'foo'}
      selected_items = {cls1.id => cls1.name}
      edit = {
        :new            => new,
        :old_name       => cls1.name,
        :fqname         => cls1.fqname,
        :typ            => MiqAeClass,
        :rec_id         => cls1.id,
        :key            => "copy_objects__#{cls1.id}",
        :current        => new,
        :selected_items => selected_items,
      }
      controller.instance_variable_set(:@_params, :button => "copy", :id => cls1.id)
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, :action => "miq_ae_class_copy")
      session[:edit] = edit
      allow(controller).to receive(:replace_right_cell)
      controller.send(:copy_objects)
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:record).name).to eq('foo')
      expect(assigns(:flash_array).first[:message]).to include("Copy selected Automate Class was saved")
    end
  end

  context "get selected Class/Instance/Method record back" do
    let(:miq_ae_domain) { double("MiqAeDomain", :name => "yet_another_fqname", :id => 1) }
    let(:miq_ae_domain2) { double("MiqAeDomain", :name => "yet_another_fqname2", :id => 2) }

    let(:miq_ae_class) do
      double("MiqAeClass",
                                    :id           => 1,
                                    :fqname       => "cls_fqname",
                                    :display_name => "FOO",
                                    :name         => "foo",
                                    :ae_fields    => [],
                                    :ae_instances => [],
                                    :ae_methods   => [],
                                    :domain       => miq_ae_domain2
                                   )
    end

    let(:miq_ae_instance) do
      double("MiqAeInstance",
                                    :id           => 123,
                                    :display_name => "some name",
                                    :name         => "some_name",
                                    :fqname       => "fqname",
                                    :created_on   => Time.now,
                                    :updated_on   => Time.current,
                                    :updated_by   => "some_user",
                                    :domain       => miq_ae_domain
                                   )
    end

    let(:miq_ae_method) do
      double("MiqAeMethod",
                                    :id           => 123,
                                    :display_name => "some name",
                                    :inputs       => [],
                                    :name         => "some_name",
                                    :fqname       => "fqname",
                                    :created_on   => Time.now,
                                    :updated_on   => Time.current,
                                    :updated_by   => "some_user",
                                    :domain       => miq_ae_domain
                                   )
    end

    let(:override) do
      double("MiqAeClass",
                                    :fqname => "another_fqname/fqname",
                                    :id     => 1,
                                    :domain => miq_ae_domain
                                   )
    end
    let(:override2) do
      double("MiqAeClass",
                                    :fqname => "another_fqname2/fqname",
                                    :id     => 2,
                                    :domain => miq_ae_domain2
                                   )
    end

    before do
      @user =  FactoryGirl.create(:user_with_group)
      login_as @user
      allow(MiqAeDomain).to receive(:find_by_name).with("another_fqname").and_return(miq_ae_domain)
      allow(MiqAeDomain).to receive(:find_by_name).with("another_fqname2").and_return(miq_ae_domain2)
    end

    context "#node_info" do
      it "collect namespace info" do
        stub_user(:features => :all)
        d1 = FactoryGirl.create(:miq_ae_domain, :name => "domain1")
        ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
        FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => ns1.id)
        FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)
        node = "aen-#{ns1.id}"
        controller.instance_variable_set(:@sb,
                                         :active_tree => :ae_tree,
                                         :trees       => {:ae_tree => {:active_node => node}})
        controller.send(:get_node_info, node)
        expect(assigns(:sb)[:namespace_path]).to eq(ns1.fqname.gsub!(%r{\/}, " / "))
      end
    end

    context "#get_instance_node_info" do
      context "when record does not exist" do
        it "sets active node back to root" do
          id = %w(aei some_id)
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => "aei-some_id"}})
          controller.send(:get_instance_node_info, id)
          expect(assigns(:sb)[:trees][:ae_tree][:active_node]).to eq("root")
        end
      end

      context "when the record exists" do
        before do
          allow(MiqAeInstance).to receive(:find_by_id).with(123).and_return(miq_ae_instance)
          allow(miq_ae_instance).to receive(:ae_class).and_return(miq_ae_class)
          allow(MiqAeInstance).to receive(:get_homonymic_across_domains)
            .with(@user, "fqname").and_return([override, override2])
        end

        it "return instance record and check count of override instances being returned" do
          id = ["aei", miq_ae_instance.id]
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => id.join("-")}})
          controller.send(:get_instance_node_info, id)
          expect(assigns(:record).name).to eq(miq_ae_instance.name)
          expect(assigns(:domain_overrides).count).to eq(2)
          expect(assigns(:right_cell_text)).to include("Automate Instance [#{miq_ae_instance.display_name}")
        end
      end
    end

    context "#get_class_node_info" do
      context "when record does not exist" do
        it "sets active node back to root" do
          id = %w(aec some_id)
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => "aec-some_id"}})
          controller.send(:get_instance_node_info, id)
          expect(assigns(:sb)[:trees][:ae_tree][:active_node]).to eq("root")
        end
      end

      context "when the record exists" do
        before do
          allow(MiqAeClass).to receive(:find_by_id).with(1).and_return(miq_ae_class)
          allow(MiqAeClass).to receive(:get_homonymic_across_domains)
            .with(@user, "cls_fqname").and_return([override, override2])
        end

        it "returns class record and check count of override classes being returned" do
          id = ["aec", miq_ae_class.id]
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => id.join("-")}})
          controller.send(:get_class_node_info, id)
          expect(assigns(:record).name).to eq(miq_ae_class.name)
          expect(assigns(:domain_overrides).count).to eq(2)
          expect(assigns(:right_cell_text)).to include(miq_ae_class.display_name)
        end
      end
    end

    context "#get_method_node_info" do
      context "when record does not exist" do
        it "sets active node back to root" do
          id = %w(aem some_id)
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => "aem-some_id"}})
          controller.send(:get_instance_node_info, id)
          expect(assigns(:sb)[:trees][:ae_tree][:active_node]).to eq("root")
        end
      end

      context "when the record exists" do
        before do
          allow(MiqAeMethod).to receive(:find_by_id).with(123).and_return(miq_ae_method)
          allow(miq_ae_method).to receive(:ae_class).and_return(miq_ae_class)
          allow(MiqAeMethod).to receive(:get_homonymic_across_domains)
            .with(@user, "fqname").and_return([override, override2])
        end

        it "returns method record and check count of override methods being returned" do
          id = ["aem", miq_ae_method.id]
          controller.instance_variable_set(:@sb,
                                           :active_tree => :ae_tree,
                                           :trees       => {:ae_tree => {:active_node => id.join("-")}})
          controller.send(:get_method_node_info, id)
          expect(assigns(:record).name).to eq(miq_ae_method.name)
          expect(assigns(:domain_overrides).count).to eq(2)
          expect(assigns(:right_cell_text)).to include("Automate Method [#{miq_ae_method.display_name}")
        end
      end
    end
  end

  context "#delete_domain" do
    it "Should only delete editable domains" do
      stub_user(:features => :all)
      domain1 = FactoryGirl.create(:miq_ae_system_domain_enabled)

      domain2 = FactoryGirl.create(:miq_ae_domain_enabled)
      controller.instance_variable_set(:@_params,
                                       :miq_grid_checks => "aen-#{domain1.id}, aen-#{domain2.id}, aen-someid"
                                      )
      allow(controller).to receive(:replace_right_cell)
      controller.send(:delete_domain)
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("cannot be deleted")
      expect(flash_messages.first[:level]).to eq(:error)
      expect(flash_messages.last[:message]).to include("Delete successful")
      expect(flash_messages.last[:level]).to eq(:success)
    end
  end

  context "#ae_class_validation" do
    before(:each) do
      stub_user(:features => :all)
      ns = FactoryGirl.create(:miq_ae_namespace)
      @cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      @cls.ae_fields << FactoryGirl.create(:miq_ae_field, :name => 'fred',
                                           :class_id => @cls.id, :priority => 1)
      @cls.save
      @method = FactoryGirl.create(:miq_ae_method, :name => "method01", :scope => "class",
        :language => "ruby", :class_id => @cls.id, :data => "exit MIQ_OK", :location => "inline")
      expect(controller).to receive(:render)
      controller.instance_variable_set(:@sb, :trees       => {:ae_tree => {:active_node => "aec-#{@cls.id}"}},
                                             :active_tree => :ae_tree)
      session[:edit] = {
        :key         => "aefields_edit__#{@cls.id}",
        :ae_class_id => @cls.id,
        :new         => {
          :datatypes => [],
          :aetypes   => [],
          :fields    => []
        }
      }
    end

    after(:each) do
      expect(controller.send(:flash_errors?)).to be_truthy
      expect(assigns(:edit)).not_to be_nil
      expect(response.status).to eq(200)
    end

    it "Should not allow to accept schema field without name" do
      field = {:aetype   => "attribute"}
      controller.instance_variable_set(:@edit, session[:edit])
      session[:field_data] = field
      controller.instance_variable_set(:@_params, :button => "accept", :id => @cls.id)
      controller.send(:field_accept)

      expect(assigns(:flash_array).first[:message]).to include("Name is required")
    end

    it "Should not allow to accept schema field without type" do
      field = {:name   => "name"}
      controller.instance_variable_set(:@edit, session[:edit])
      session[:field_data] = field
      controller.instance_variable_set(:@_params, :button => "accept", :id => @cls.id)
      controller.send(:field_accept)

      expect(assigns(:flash_array).first[:message]).to include("Type is required")
    end

    it "Should not allow to accept schema field without name and type" do
      field = {}
      controller.instance_variable_set(:@edit, session[:edit])
      session[:field_data] = field
      controller.instance_variable_set(:@_params, :button => "accept", :id => @cls.id)
      controller.send(:field_accept)

      expect(assigns(:flash_array).first[:message]).to include("Name and Type is required")
    end

    it "Should not allow to create two schema fields with identical name" do
      field = {"aetype"   => "attribute",
               "datatype" => "string",
               "name"     => "name01"}
      session[:edit][:new][:fields] = [field, field]
      controller.instance_variable_set(:@_params, :button => "save", :id => @cls.id)
      controller.send(:update_fields)
      expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
    end

    it "Should not allow to add two parameters with identical name to a method" do
      field = {"default_value" => nil,
               "datatype"      => nil,
               "name"          => "name01",
               "method_id"     => @method.id}
      session[:edit] = {
        :key         => "aemethod_edit__#{@method.id}",
        :ae_class_id => @cls.id,
        :new_field   => {},
        :new         => {
          :name   => @method.name,
          :fields => [field, field]
        }
      }
      controller.instance_variable_set(:@_params, :button => "save", :id => @method.id)
      controller.send(:update_method)
      expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
    end

    it "Should not allow to add two parameters with identical name to a newly created method" do
      field = {"default_value" => nil,
               "datatype"      => nil,
               "name"          => "name01",
               "method_id"     => nil}
      session[:edit] = {
        :key         => "aemethod_edit__new",
        :ae_class_id => @cls.id,
        :new_field   => {},
        :new         => {
          :name         => "method01",
          :display_name => nil,
          :fields       => [field, field],
          :scope        => "instance",
          :language     => "ruby"
        }
      }
      controller.instance_variable_set(:@_params, :button => "add")
      controller.send(:create_method)
      expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
    end
  end

  context "save class/method" do
    before do
      stub_user(:features => :all)
      ns = FactoryGirl.create(:miq_ae_namespace)
      @cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      @cls.ae_fields << FactoryGirl.create(:miq_ae_field, :name => 'fred',
                                           :class_id => @cls.id, :priority => 1)
      @cls.save
      @method = FactoryGirl.create(:miq_ae_method, :name => "method01", :scope => "class",
        :language => "ruby", :class_id => @cls.id, :data => "exit MIQ_OK", :location => "inline")
      allow(controller).to receive(:replace_right_cell)
      controller.instance_variable_set(:@sb, :trees       => {:ae_tree => {:active_node => "aec-#{@cls.id}"}},
                                             :active_tree => :ae_tree)
    end

    it "update a method with inputs" do
      field = {"default_value" => nil,
               "datatype"      => nil,
               "name"          => "name01",
               "method_id"     => @method.id}
      session[:edit] = {
        :key              => "aemethod_edit__#{@method.id}",
        :fields_to_delete => [],
        :ae_class_id      => @cls.id,
        :new_field        => {},
        :new              => {
          :name     => @method.name,
          :language => 'ruby',
          :scope    => 'instance',
          :location => 'inline',
          :fields   => [field]
        }
      }
      controller.instance_variable_set(:@_params, :button => "save", :id => @method.id)
      controller.send(:update_method)
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.status).to eq(200)
    end

    it "update a class with fields" do
      field = {"aetype"   => "attribute",
               "datatype" => "string",
               "name"     => "name01"}
      session[:edit] = {
        :key              => "aefields_edit__#{@cls.id}",
        :ae_class_id      => @cls.id,
        :fields_to_delete => [],
        :new              => {
          :datatypes => [],
          :aetypes   => [],
          :fields    => [field]
        }
      }
      controller.instance_variable_set(:@_params, :button => "save", :id => @cls.id)
      controller.send(:update_fields)
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.status).to eq(200)
    end
  end

  context "#copy_objects_edit_screen" do
    it "sets only current tenant's domains to be displayed in To Domain pull down" do
      FactoryGirl.create(:miq_ae_domain, :tenant => Tenant.seed)
      FactoryGirl.create(:miq_ae_domain, :tenant => FactoryGirl.create(:tenant))
      controller.instance_variable_set(:@sb, {})
      ns = FactoryGirl.create(:miq_ae_namespace)
      controller.send(:copy_objects_edit_screen, MiqAeNamespace, [ns.id], "miq_ae_namespace_copy")
      expect(assigns(:edit)[:domains].count).to eq(1)
    end
  end

  context "#delete_namespaces_or_classes" do
    before do
      stub_user(:features => :all)
      domain = FactoryGirl.create(:miq_ae_domain, :tenant => Tenant.seed)
      @namespace = FactoryGirl.create(:miq_ae_namespace, :name => "foo_namespace", :parent => domain)
      @ae_class = FactoryGirl.create(:miq_ae_class, :name => "foo_class", :namespace_id => 1)
      controller.instance_variable_set(:@sb,
                                       :trees       => {},
                                       :active_tree => :ae_tree)
      allow(controller).to receive(:replace_right_cell)
      controller.x_node = "aen-#{@namespace.compressed_id}"
    end


    it "Should delete multiple selected items from list" do
      controller.instance_variable_set(:@_params,
                                       :miq_grid_checks => "aec-#{@ae_class.id},aen-#{@namespace.id}",
                                       :id              => @namespace.id
      )
      controller.send(:delete_namespaces_or_classes)
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("Automate Namespace \"foo_namespace\": Delete successful")
      expect(flash_messages.last[:message]).to include("Automate Class \"foo_class\": Delete successful")
    end

    it "Should delete selected namespace in the tree" do
      controller.instance_variable_set(:@_params,
                                       :id => @namespace.id
      )

      controller.send(:delete_namespaces_or_classes)
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("Automate Namespace \"foo_namespace\": Delete successful")
    end
  end

  context "#deleteclasses" do
    before do
      stub_user(:features => :all)
      domain = FactoryGirl.create(:miq_ae_domain, :tenant => Tenant.seed)
      @namespace = FactoryGirl.create(:miq_ae_namespace, :name => "foo_namespace", :parent => domain)
      @ae_class = FactoryGirl.create(:miq_ae_class, :name => "foo_class", :namespace_id => @namespace.id)
      controller.instance_variable_set(:@sb,
                                       :trees       => {},
                                       :active_tree => :ae_tree)
      allow(controller).to receive(:replace_right_cell)
    end

    it "Should delete selected class in the tree" do
      controller.x_node = "aec-#{@ae_class.compressed_id}"
      controller.instance_variable_set(:@_params,
                                       :id => @namespace.id
      )

      controller.send(:deleteclasses)
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("Automate Class \"foo_class\": Delete successful")
      expect(controller.x_node).to eq("aen-#{@namespace.compressed_id}")
    end
  end

  context "#set_field_vars" do
    it "sets priority of new schema fields" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      field1 = FactoryGirl.create(:miq_ae_field,
                                  :aetype   => "attribute",
                                  :datatype => "string",
                                  :name     => "name01",
                                  :class_id => cls.id,
                                  :priority => 1)
      field2 = FactoryGirl.create(:miq_ae_field,
                                  :aetype   => "attribute",
                                  :datatype => "string",
                                  :name     => "name02",
                                  :class_id => cls.id,
                                  :priority => 2)
      field3 = {"aetype"   => "attribute",
                "datatype" => "string",
                "name"     => "name03"}
      edit = {:fields_to_delete => [], :new => {:fields => [field2, field3, field1]}}
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@ae_class, cls)
      fields = controller.send(:set_field_vars, cls)
      priorities = fields.collect(&:priority)
      expect(priorities).to eq([1, 2, 3])
    end
  end

  context "#fields_seq_field_changed" do
    before do
      ns = FactoryGirl.create(:miq_ae_namespace, :name => 'foo')
      @cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      FactoryGirl.create(:miq_ae_field,
                         :aetype   => "attribute",
                         :datatype => "string",
                         :name     => "name01",
                         :class_id => @cls.id,
                         :priority => 1)
      FactoryGirl.create(:miq_ae_field,
                         :aetype   => "attribute",
                         :datatype => "string",
                         :name     => "name02",
                         :class_id => @cls.id,
                         :priority => 2)
    end

    it "moves selected field down" do
      controller.send(:fields_seq_edit_screen, @cls.id)
      expect(assigns(:edit)[:new][:fields_list]).to match_array(["(name01)", "(name02)"])
      controller.instance_variable_set(:@_params, :button => 'down', :id => 'seq', :seq_fields => "['(name01)']")
      expect(controller).to receive(:render)
      controller.fields_seq_field_changed
      expect(assigns(:edit)[:new][:fields_list]).to match_array(["(name02)", "(name01)"])
    end

    it "moves selected field up" do
      controller.send(:fields_seq_edit_screen, @cls.id)
      expect(assigns(:edit)[:new][:fields_list]).to match_array(["(name01)", "(name02)"])
      controller.instance_variable_set(:@_params, :button => 'up', :id => 'seq', :seq_fields => "['(name02)']")
      expect(controller).to receive(:render)
      controller.fields_seq_field_changed
      expect(assigns(:edit)[:new][:fields_list]).to match_array(["(name02)", "(name01)"])
    end
  end
end
