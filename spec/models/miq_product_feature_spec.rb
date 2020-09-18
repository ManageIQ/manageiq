RSpec.describe MiqProductFeature do
  let(:miq_product_feature_class) do
    Class.new(described_class) do
      def self.with_parent_tenant_nodes
        includes(:parent).where(:parents_miq_product_features => {:identifier => self::TENANT_FEATURE_ROOT_IDENTIFIERS})
      end

      def self.tenant_features_in_hash
        with_parent_tenant_nodes.map { |x| x.slice(:name, :description, :identifier, :tenant_id) }
      end
    end
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:miq_product_feature, :identifier => "some_feature")
    expect { m.valid? }.not_to make_database_queries
  end

  # - container_dashboard
  # - miq_report_widget_editor
  #   - miq_report_widget_admin
  #     - widget_edit
  #     - widget_copy
  #     - widget_refresh (H)
  let(:hierarchical_features) do
    EvmSpecHelper.seed_specific_product_features(
      %w(miq_report_widget_editor miq_report_widget_admin widget_refresh widget_edit widget_copy container_dashboard)
    )
  end

  def assert_product_feature_attributes(pf)
    expect(pf).to include(*described_class::REQUIRED_ATTRIBUTES)
    expect(pf.keys - described_class::ALLOWED_ATTRIBUTES).to be_empty
    pf.each do |k, v|
      next if k == :hidden
      expect(v).not_to be_blank, "Identifier: '#{pf[:identifier]}'  Key: '#{k}' is blank"
    end
  end

  def traverse_product_feature_children(pfs, &block)
    pfs.each do |pf|
      yield pf
      traverse_product_feature_children(pf[:children], &block) if pf.key?(:children)
    end
  end

  it "is properly configured" do
    root_file, other_files = described_class.seed_files

    hash = YAML.load_file(root_file)
    assert_product_feature_attributes(hash)

    traverse_product_feature_children(hash[:children]) do |pf|
      assert_product_feature_attributes(pf)
    end

    other_files.each do |f|
      hash = YAML.load_file(f)
      traverse_product_feature_children(Array.wrap(hash)) do |pf|
        assert_product_feature_attributes(pf)
      end
    end
  end

  context ".seed" do
    it "creates feature identifiers once on first seed, changes nothing on second seed" do
      expect { MiqProductFeature.seed }.to change(MiqProductFeature, :count)
      orig_ids = MiqProductFeature.pluck(:id)
      expect { MiqProductFeature.seed }.not_to change(MiqProductFeature, :count)
      expect(MiqProductFeature.pluck(:id)).to match_array orig_ids
    end
  end

  context ".seed_features" do
    let(:tempdir)      { Dir.mktmpdir }
    let(:feature_path) { File.join(tempdir, "miq_product_features") }
    let(:root_file)    { File.join(tempdir, "miq_product_features.yml") }

    let(:base) do
      {
        :feature_type => "node",
        :identifier   => "everything",
        :children     => [
          {
            :feature_type => "node",
            :identifier   => "dialog_new_editor",
            :name         => "One",
            :children     => []
          }
        ]
      }
    end

    before do
      File.write(root_file, base.to_yaml)

      expect(described_class).to receive(:seed_files).at_least(:once) do
        [root_file, Dir.glob(File.join(feature_path, "*.yml"))]
      end
    end

    after do
      FileUtils.rm_rf(tempdir)
    end

    it "creates/updates/deletes records" do
      deleted   = FactoryBot.create(:miq_product_feature, :identifier => "xxx")
      changed   = FactoryBot.create(:miq_product_feature, :identifier => "dialog_new_editor", :name => "XXX")
      unchanged = FactoryBot.create(:miq_product_feature_everything)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqProductFeature.seed_features

      expect { deleted.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(changed.reload.name).to eq("One")
      expect(unchanged.reload.updated_at).to be_within(0.1).of unchanged_orig_updated_at
    end

    context "additional yaml feature" do
      before do
        additional_hash = {
          :feature_type => "node",
          :identifier   => "dialog_edit_editor",
          :children     => []
        }

        additional_array = [
          {
            :feature_type => "node",
            :identifier   => "policy_edit_editor",
            :children     => []
          }
        ]

        FileUtils.mkdir_p(feature_path)
        File.write(File.join(feature_path, "additional_hash.yml"), additional_hash.to_yaml)
        File.write(File.join(feature_path, "additional_array.yml"), additional_array.to_yaml)
      end

      it "creates/updates/deletes records" do
        MiqProductFeature.seed_features

        expect(MiqProductFeature.pluck(:identifier)).to match_array %w(everything dialog_new_editor dialog_edit_editor policy_edit_editor)
      end
    end

    context 'dynamic product features' do
      context 'add new' do
        let(:base) do
          {
            :feature_type => "node",
            :identifier   => "everything",
            :children     => [
              {
                :feature_type => "node",
                :identifier   => "one",
                :name         => "One",
                :children     => [
                  {
                    :feature_type => "admin",
                    :identifier   => "dialog_copy_editor",
                    :name         => "Edit",
                    :description  => "XXX"
                  }
                ]
              }
            ]
          }
        end

        let(:root_tenant) do
          Tenant.seed
          Tenant.default_tenant
        end

        let!(:tenant) { FactoryBot.create(:tenant, :parent => root_tenant) }

        before do
          MiqProductFeature.seed_features
        end

        it "creates tenant features" do
          features = miq_product_feature_class.tenant_features_in_hash
          expect(features).to match_array([{ "name" => "Edit (#{root_tenant.name})", "description" => "XXX for tenant #{root_tenant.name}",
                                               "identifier" => "dialog_copy_editor_tenant_#{root_tenant.id}", "tenant_id" => root_tenant.id},
                                           {"name" => "Edit (#{tenant.name})", "description" => "XXX for tenant #{tenant.name}",
                                            "identifier" => "dialog_copy_editor_tenant_#{tenant.id}", "tenant_id" => tenant.id}])

          expect(MiqProductFeature.where(:identifier => "dialog_copy_editor", :name => "Edit").count).to eq(1)
        end

        context "with tenants from remote region" do
          before do
            MiqRegion.seed
          end

          def id_for_model_in_region(model, region)
            model.id_in_region(model.count + 1_000_000, region.region)
          end

          let!(:other_miq_region) { FactoryBot.create(:miq_region) }
          let!(:tenant_product_feature_other_region) do
            Tenant.skip_callback(:create, :after, :create_miq_product_features_for_tenant_nodes)
            tenant = FactoryGirl.create(:tenant, :id => id_for_model_in_region(Tenant, other_miq_region))
            Tenant.set_callback(:create, :after, :create_miq_product_features_for_tenant_nodes)

            tenant
          end

          it "doesn't seed tenant features for tenants from remote regions" do
            MiqProductFeature.seed_tenant_miq_product_features
            expect(tenant_product_feature_other_region.miq_product_features.to_a).to be_empty

            expect(tenant.miq_product_features.map(&:identifier)).to match_array(["dialog_copy_editor_tenant_#{tenant.id}"])
          end
        end

        context "add tenant node product features" do
          let(:base) do
            {
              :feature_type => "node",
              :identifier   => "everything",
              :children     => [
                {
                  :feature_type => "node",
                  :identifier   => "one",
                  :name         => "One",
                  :children     => [
                    {
                      :feature_type => "admin",
                      :identifier   => "dialog_copy_editor",
                      :name         => "Edit",
                      :description  => "XXX"
                    }
                  ]
                },
                {
                  :feature_type => "admin",
                  :identifier   => "dialog_delete",
                  :name         => "Add",
                  :description  => "YYY"
                }
              ]
            }
          end

          it "add new tenant feature" do
            features = miq_product_feature_class.tenant_features_in_hash
            expect(features).to match_array([{ "name" => "Edit (#{root_tenant.name})", "description" => "XXX for tenant #{root_tenant.name}",
                                               "identifier" => "dialog_copy_editor_tenant_#{root_tenant.id}", "tenant_id" => root_tenant.id},
                                             {"name" => "Edit (#{tenant.name})", "description" => "XXX for tenant #{tenant.name}",
                                              "identifier" => "dialog_copy_editor_tenant_#{tenant.id}", "tenant_id" => tenant.id},
                                             {"name" => "Add (#{root_tenant.name})", "description" => "YYY for tenant #{root_tenant.name}",
                                              "identifier" => "dialog_delete_tenant_#{root_tenant.id}", "tenant_id" => root_tenant.id},
                                             {"name" => "Add (#{tenant.name})", "description" => "YYY for tenant #{tenant.name}",
                                              "identifier" => "dialog_delete_tenant_#{tenant.id}", "tenant_id" => tenant.id}])

            expect(MiqProductFeature.where(:identifier => "dialog_delete", :name => "Add").count).to eq(1)
          end

          context "remove added tenant feaure" do
            let(:base) do
              {
                :feature_type => "node",
                :identifier   => "everything",
                :children     => [
                  {
                    :feature_type => "node",
                    :identifier   => "one",
                    :name         => "One",
                    :children     => [
                      {
                        :feature_type => "admin",
                        :identifier   => "dialog_copy_editor",
                        :name         => "Edit",
                        :description  => "XXX"
                      }
                    ]
                  }
                ]
              }
            end

            it "removes tenant features" do
              features = miq_product_feature_class.tenant_features_in_hash

              expect(features).to match_array([{ "name" => "Edit (#{root_tenant.name})", "description" => "XXX for tenant #{root_tenant.name}",
                                                 "identifier" => "dialog_copy_editor_tenant_#{root_tenant.id}", "tenant_id" => root_tenant.id},
                                               {"name" => "Edit (#{tenant.name})", "description" => "XXX for tenant #{tenant.name}",
                                                "identifier" => "dialog_copy_editor_tenant_#{tenant.id}", "tenant_id" => tenant.id}])

              expect(MiqProductFeature.where(:identifier => "dialog_copy_editor", :name => "Edit").count).to eq(1)
            end
          end
        end
      end
    end
  end

  describe '#feature_children' do
    it "returns only visible features" do
      hierarchical_features
      expect(MiqProductFeature).not_to receive(:sort_children)
      expect(MiqProductFeature.feature_children("miq_report_widget_admin", false)).to match_array(%w(widget_copy widget_edit))
    end

    it "returns direct children only" do
      hierarchical_features
      expect(MiqProductFeature.feature_children("miq_report_widget_editor")).to match_array(%w(miq_report_widget_admin))
    end

    it "sorts features" do
      hierarchical_features
      expect(MiqProductFeature).to receive(:sort_children).and_call_original
      expect(MiqProductFeature.feature_children("miq_report_widget_admin")).to match_array(%w(widget_copy widget_edit))
    end
  end

  describe '#feature_all_children' do
    it "returns all visible children" do
      hierarchical_features
      expect(MiqProductFeature).not_to receive(:sort_children)
      expect(MiqProductFeature.feature_all_children("miq_report_widget_editor", false)).to match_array(
        %w(widget_copy widget_edit miq_report_widget_admin))
    end

    it "returns all visible children sorted" do
      hierarchical_features
      expect(MiqProductFeature).to receive(:sort_children).and_call_original
      expect(MiqProductFeature.feature_all_children("miq_report_widget_editor")).to eq(
        %w(widget_copy widget_edit miq_report_widget_admin))
    end
  end

  describe "#feature_details" do
    it "returns data for visible features" do
      EvmSpecHelper.seed_specific_product_features("container_dashboard")
      expect(MiqProductFeature.feature_details("container_dashboard")).to be_truthy
    end

    it "eats hidden features" do
      EvmSpecHelper.seed_specific_product_features("widget_refresh")
      expect(MiqProductFeature.feature_details("widget_refresh")).not_to be
    end
  end

  describe "#feature_hidden" do
    it "detects visible features" do
      EvmSpecHelper.seed_specific_product_features("container_dashboard")
      expect(MiqProductFeature.feature_hidden("container_dashboard")).not_to be
    end

    it "detects hidden features" do
      EvmSpecHelper.seed_specific_product_features("widget_refresh")
      expect(MiqProductFeature.feature_hidden("widget_refresh")).to be_truthy
    end
  end

  describe ".features" do
    before { MiqProductFeature.instance_variable_set(:@feature_cache, nil) }
    after  { MiqProductFeature.instance_variable_set(:@feature_cache, nil) }

    #      1
    #    2    3
    #        4 5
    it "populates parent and children" do
      f1 = FactoryBot.create(:miq_product_feature, :identifier => "f1", :name => "F1n")
      FactoryBot.create(:miq_product_feature, :identifier => "f2", :name => "F2n", :parent_id => f1.id)
      f3 = FactoryBot.create(:miq_product_feature, :identifier => "f3", :name => "F3n", :parent_id => f1.id)
      FactoryBot.create(:miq_product_feature, :identifier => "f4", :name => "F4n", :parent_id => f3.id)
      FactoryBot.create(:miq_product_feature, :identifier => "f5", :name => "F5n", :parent_id => f3.id)
      MiqProductFeature.attribute_names # 0..1 queries
      Tenant.attribute_names # 0..1 queries

      expect { MiqProductFeature.features }.to make_database_queries(:count => 1..2)
      expect { MiqProductFeature.features }.to_not make_database_queries

      expect(MiqProductFeature.feature_root).to eq("f1")
      expect(MiqProductFeature.feature_children("f1")).to match_array(%w(f2 f3))
      expect(MiqProductFeature.feature_children("f2")).to match_array([])
      expect(MiqProductFeature.feature_children("f3")).to match_array(%w(f4 f5))

      expect(MiqProductFeature.feature_parent("f1")).to be_nil
      expect(MiqProductFeature.feature_parent("f2")).to eq("f1")
      expect(MiqProductFeature.feature_parent("f4")).to eq("f3")
    end
  end

  describe "feature object cache" do
    let!(:f0) { FactoryBot.create(:miq_product_feature, :identifier => "everything", :name => "F0n") }
    let!(:f1) { FactoryBot.create(:miq_product_feature, :identifier => "f1", :name => "F1n", :parent_id => f0.id) }
    let!(:f2) { FactoryBot.create(:miq_product_feature, :identifier => "f2", :name => "F2n", :parent_id => f1.id) }
    let!(:f3) { FactoryBot.create(:miq_product_feature, :identifier => "f3", :name => "F3n", :parent_id => f1.id) }
    let!(:f4) { FactoryBot.create(:miq_product_feature, :identifier => "f4", :name => "F4n", :parent_id => f3.id) }
    let!(:f5) { FactoryBot.create(:miq_product_feature, :identifier => "f5", :name => "F5n", :parent_id => f3.id) }

    it "memoizes hash to prevent extra db queries" do
      expect { MiqProductFeature.obj_features }.to make_database_queries(:count => 1)
      expect { MiqProductFeature.obj_features }.to_not make_database_queries
    end

    it "builds a hash with feature objects keyed by identifier" do
      expect(MiqProductFeature.obj_features["f1"][:feature]).to eq(f1)
    end

    it "builds a hash of features objects with child objects" do
      expect(MiqProductFeature.feature_root).to eq("everything")
      expect(MiqProductFeature.obj_feature_children("f1")).to match_array([f2, f3])
      expect(MiqProductFeature.obj_feature_children("f2")).to match_array([])
      expect(MiqProductFeature.obj_feature_children("f3")).to match_array([f4, f5])
    end

    it "references the parent by identifier" do
      expect(MiqProductFeature.obj_feature_parent("everything")).to be_nil
      expect(MiqProductFeature.obj_feature_parent("f2")).to eq("f1")
      expect(MiqProductFeature.obj_feature_parent("f4")).to eq("f3")
    end

    it "finds the ancestors of a feature" do
      ancestors = MiqProductFeature.obj_feature_ancestors("f4")

      expect(ancestors.count).to eq(3)
      expect(ancestors).to include(f0)
      expect(ancestors).to include(f3)
      expect(ancestors).to include(f1)
    end

    it "handles bad feature names" do
      expect(MiqProductFeature.obj_feature_ancestors("foo")).to eq([])
      expect(MiqProductFeature.obj_feature_children("foo")).to be_nil
      expect(MiqProductFeature.obj_feature_all_children("foo")).to be_nil
    end
  end
end
