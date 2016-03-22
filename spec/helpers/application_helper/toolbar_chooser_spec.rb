describe ApplicationHelper, "ToolbarChooser" do
  describe "generate explorer toolbar file names" do
    context "#center_toolbar_filename_classic (private)" do
      before do
        @view   = true
        @layout = "miq_request_vm"
      end

      it "miq_request summary screen" do
        @lastaction = "show"
        expect(_toolbar_chooser.send(:center_toolbar_filename_classic)).to eq("miq_request_center_tb")
      end

      it "miq_request list screen" do
        @lastaction = "show_list"
        %w(miq_request_ae miq_request_host miq_request_vm).each do |layout|
          @layout = layout
          expect(_toolbar_chooser.send(:center_toolbar_filename_classic)).to eq("miq_requests_center_tb")
        end
      end
    end

    context "#center_toolbar_filename_automate (private)" do
      before { @sb = {:active_tree => :ae_tree, :trees => {:ae_tree => {:tree => :ae_tree}}} }

      it "should return domains toolbar on root node" do
        x_node_set('root', :ae_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_domains_center_tb")
      end

      it "should return namespaces toolbar on domain node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10)
        x_node_set("aen-#{n1.id}", :ae_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_domain_center_tb")
      end

      it "should return namespace toolbar on namespace node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_domain))
        x_node_set("aen-#{n1.id}", :ae_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_namespace_center_tb")
      end

      it "should return tab specific toolbar on class node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :parent => FactoryGirl.create(:miq_ae_domain))
        c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
        x_node_set("aec-#{c1.id}", :ae_tree)

        @sb[:active_tab] = "props"
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_class_center_tb")

        @sb[:active_tab] = "methods"
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_methods_center_tb")

        @sb[:active_tab] = "schema"
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_fields_center_tb")

        @sb[:active_tab] = ""
        expect(_toolbar_chooser.send(:center_toolbar_filename_automate)).to eq("miq_ae_instances_center_tb")
      end
    end
  end
end
