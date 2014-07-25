require "spec_helper"

describe MiqAeClassController do
  context "#set_record_vars" do
    it "Namespace remains unchanged when a class is edited" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      ns_id = cls.namespace_id
      new = {:name => "New Name", :description => "New Description", :display_name => "Display Name", :inherits => "Some_Class"}
      controller.instance_variable_set(:@sb,
                                       {:trees => {
                                           :ae_tree => {:active_node => "aec-#{cls.id}"}
                                       },
                                        :active_tree => :ae_tree
                                       })
      controller.instance_variable_set(:@edit, {:new => new})
      controller.send(:set_record_vars, cls)
      cls.namespace_id.should == ns_id
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
      assigns(:sb)[:namespace_path].should == fq_name.gsub!(/\//," / ")

      id = "root"
      fq_name = ""
      controller.send(:set_right_cell_text, id)
      assigns(:sb)[:namespace_path].should == fq_name
    end
  end

  context "#domain_lock" do
    it "Marks domain as locked/readonly" do
      set_user_privileges
      ns = FactoryGirl.create(:miq_ae_domain_enabled)
      controller.instance_variable_set(:@_params, :id => ns.id)
      controller.stub(:replace_right_cell)
      controller.send(:domain_lock)
      ns.reload
      ns.system.should == true
    end
  end

  context "#domain_unlock" do
    it "Marks domain as unlocked/editable" do
      set_user_privileges
      ns = FactoryGirl.create(:miq_ae_domain_disabled)
      controller.instance_variable_set(:@_params, :id => ns.id)
      controller.stub(:replace_right_cell)
      controller.send(:domain_unlock)
      ns.reload
      ns.system.should == false
    end
  end

  context "#domains_priority_edit" do
    it "sets priority of domains" do
      set_user_privileges
      FactoryGirl.create(:miq_ae_namespace, :name => "test1", :parent => nil, :priority => 1)
      FactoryGirl.create(:miq_ae_namespace, :name => "test2", :parent => nil, :priority => 2)
      FactoryGirl.create(:miq_ae_namespace, :name => "test3", :parent => nil, :priority => 3)
      FactoryGirl.create(:miq_ae_namespace, :name => "test4", :parent => nil, :priority => 4)
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
      controller.stub(:replace_right_cell)
      controller.send(:domains_priority_edit)
      domain_order = []
      MiqAeDomain.order('priority ASC').collect { |d| domain_order.push(d.name) unless d.priority == 0 }
      domain_order.should eq(edit[:new][:domain_order])
    end
  end

  context "#copy_objects" do
    it "copies class under specified namespace" do
      set_user_privileges
      d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      d2 = FactoryGirl.create(:miq_ae_namespace,
                              :name => "domain2", :parent_id => nil, :priority => 2, :system => false)
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
      controller.stub(:replace_right_cell)
      controller.send(:copy_objects)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("Copy selected Automate Class was saved")
      MiqAeClass.find_by_name_and_namespace_id(cls1.name, ns2.id).should_not be_nil
    end

    it "copy class under same namespace returns error when class exists" do
      set_user_privileges
      d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      new = {:domain => d1.id, :namespace => ns1.fqname, :overwrite_location => false}
      edit = {
        :new     => new,
        :typ     => MiqAeClass,
        :rec_id  => cls1.id,
        :key     => "copy_objects__#{cls1.id}",
        :current => new,
      }
      controller.instance_variable_set(:@_params, :button => "copy", :id => cls1.id)
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, :action => "miq_ae_class_copy")
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.should_receive(:render)
      controller.send(:copy_objects)
      controller.send(:flash_errors?).should be_true
      assigns(:flash_array).first[:message].should include("Error during 'Automate Class copy':")
    end

    it "overwrite class under same namespace when class exists" do
      set_user_privileges
      d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => d1.id)
      cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)

      d2 = FactoryGirl.create(:miq_ae_namespace,
                              :name => "domain2", :parent_id => nil, :priority => 2, :system => false)
      ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => d2.id)

      new = {:domain => d2.id, :namespace => ns2.fqname, :overwrite_location => true}
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
      controller.stub(:replace_right_cell)
      controller.send(:copy_objects)
      controller.send(:flash_errors?).should be_false
      assigns(:flash_array).first[:message].should include("Copy selected Automate Class was saved")
    end

  end
end
