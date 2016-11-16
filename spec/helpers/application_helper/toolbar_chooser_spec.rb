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

    context "#center_toolbar for storage" do
      before { @sb = {:active_tree => :storage_tree, :trees => {:storage_tree => {:tree => :storage_tree}}} }

      it "should return storages toolbar on root node" do
        x_node_set('root', :storage_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_storage)).to eq("storages_center_tb")
      end

      it "should return storage toolbar on root node" do
        c1 = FactoryGirl.create(:storage, :name => "foo")
        x_node_set("ds-#{c1.id}", :storage_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_storage)).to eq("storage_center_tb")
      end
    end

    context "#center_toolbar for storage pod" do
      before { @sb = {:active_tree => :storage_pod_tree, :trees => {:storage_pod_tree => {:tree => :storage_pod_tree}}} }

      it "should return blank_view toolbar on root node" do
        x_node_set('root', :storage_pod_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_storage)).to eq("blank_view_tb")
      end

      it "should return storages_center toolbar on a datastore cluster node" do
        d1 = FactoryGirl.create(:storage_cluster, :name => "foo")
        x_node_set("dsc-#{d1.id}", :storage_pod_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_storage)).to eq("storages_center_tb")
      end

      it "should return storage toolbar on datastore node" do
        c1 = FactoryGirl.create(:storage, :name => "foo")
        x_node_set("ds-#{c1.id}", :storage_pod_tree)
        expect(_toolbar_chooser.send(:center_toolbar_filename_storage)).to eq("storage_center_tb")
      end
    end
  end

  describe '#x_gtl_view_tb_render?' do
    subject do
      ApplicationHelper::ToolbarChooser.new(nil, nil, :record => record, :explorer => explorer, :layout => layout)
                                       .send(:x_gtl_view_tb_render?)
    end

    context 'when record is nil' do
      let(:record) { nil }

      context 'when explorer is false' do
        let(:explorer) { false }
        let(:layout) { 'does not matter' }

        it { is_expected.to be_falsey }
      end

      context 'when explorer is true' do
        let(:explorer) { true }

        %w(
          chargeback
          generic_object_definition
          miq_ae_class
          miq_ae_customization
          miq_ae_tools
          miq_capacity_planning
          miq_capacity_utilization
          miq_policy
          miq_policy_rsop
          ops
          provider_foreman
          pxe
          report
        ).each do |layout_name|
          context "when the no_gtl_view_buttons array contains the #{layout_name} layout" do
            let(:layout) { layout_name }

            it { is_expected.to be_falsey }
          end
        end

        context 'when the no_gtl_view_buttons array does not contain the given layout' do
          let(:layout) { 'potato' }

          it { is_expected.to be_truthy }
        end
      end
    end

    context 'when record is not nil' do
      let(:record) { 'not nil' }
      let(:explorer) { 'does not matter' }
      let(:layout) { 'does not matter' }

      it { is_expected.to be_falsey }
    end
  end
end
