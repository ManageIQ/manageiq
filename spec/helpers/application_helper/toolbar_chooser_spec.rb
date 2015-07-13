require "spec_helper"

describe ApplicationHelper do
  before do
    controller.send(:extend, ApplicationHelper)
    self.class.send(:include, ApplicationHelper)
  end

  def method_missing(sym, *args)
    b = _toolbar_chooser
    if b.respond_to?(sym, true)
      b.send(sym, *args)
    else
      super
    end
  end

  context "#center_toolbar_filename_classic" do
    it "miq_request summary screen" do
      @lastaction = "show"
      @view = true
      @layout = "miq_request_vm"
      toolbar_name = center_toolbar_filename_classic
      toolbar_name.should == "miq_request_center_tb"
    end

    it "miq_request list screen" do
      @lastaction = "show_list"
      @view = true
      @layout = "miq_request_vm"
      toolbar_name = center_toolbar_filename_classic
      toolbar_name.should == "miq_requests_center_tb"
    end
  end

  describe "generate explorer toolbar file names" do
    context "#center_toolbar_filename_automate" do
      before do
        @sb = {:active_tree => :ae_tree,
               :trees       => {:ae_tree => {:tree => :ae_tree}}}
      end

      it "should return domains toolbar on root node" do
        x_node_set('root', :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_domains_center_tb")
      end

      it "should return namespaces toolbar on domain node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10)
        x_node_set("aen-#{n1.id}", :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_domain_center_tb")
      end

      it "should return namespace toolbar on namespace node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :parent_id => 1)
        x_node_set("aen-#{n1.id}", :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_namespace_center_tb")
      end

      it "should return tab specific toolbar on class node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :parent_id => 1)
        c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
        x_node_set("aec-#{c1.id}", :ae_tree)

        @sb[:active_tab] = "props"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_class_center_tb")

        @sb[:active_tab] = "methods"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_methods_center_tb")

        @sb[:active_tab] = "schema"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_fields_center_tb")

        @sb[:active_tab] = ""
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_instances_center_tb")
      end
    end
  end
end
