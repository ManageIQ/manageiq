require 'tmpdir'
require 'pathname'

describe MiqProductFeature do
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

  it "is properly configured" do
    everything = YAML.load_file(described_class.feature_yaml)
    traverse_product_features(everything) do |pf|
      expect(pf).to include(*described_class::REQUIRED_ATTRIBUTES)
      expect(pf.keys - described_class::ALLOWED_ATTRIBUTES).to be_empty
      expect(pf[:children]).not_to be_empty if pf.key?(:children)
    end
  end

  def traverse_product_features(product_feature, &block)
    block.call(product_feature)
    if product_feature.key?(:children)
      product_feature[:children].each { |child| traverse_product_features(child, &block) }
    end
  end

  context ".seed" do
    it "creates feature identifiers once on first seed, changes nothing on second seed" do
      status_seed1 = nil
      expect { status_seed1 = MiqProductFeature.seed }.to change(MiqProductFeature, :count)
      expect(status_seed1[:created]).to match_array status_seed1[:created].uniq
      expect(status_seed1[:updated]).to match_array []
      expect(status_seed1[:unchanged]).to match_array []

      status_seed2 = nil
      expect { status_seed2 = MiqProductFeature.seed }.not_to change(MiqProductFeature, :count)
      expect(status_seed2[:created]).to match_array []
      expect(status_seed2[:updated]).to match_array []
      expect(status_seed2[:unchanged]).to match_array status_seed1[:created]
    end
  end

  context ".seed_features" do
    let(:feature_path) { Pathname.new(@tempfile.path.sub(/\.yml/, '')) }
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
      @tempdir  = Dir.mktmpdir
      @tempfile = Tempfile.new(['feature', '.yml'], @tempdir)
      @tempfile.write(YAML.dump(base))
      @tempfile.close
    end

    after do
      @tempfile.unlink
      Dir.rmdir(@tempdir)
    end

    it "existing records" do
      deleted   = FactoryGirl.create(:miq_product_feature, :identifier => "xxx")
      changed   = FactoryGirl.create(:miq_product_feature, :identifier => "dialog_new_editor", :name => "XXX")
      unchanged = FactoryGirl.create(:miq_product_feature_everything)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqProductFeature.seed_features(feature_path)
      expect { deleted.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(changed.reload.name).to eq("One")
      expect(unchanged.reload.updated_at).to be_within(0.1).of unchanged_orig_updated_at
    end

    it "additional yaml feature" do
      additional = {
        :feature_type => "node",
        :identifier   => "dialog_edit_editor",
        :children     => []
      }

      Dir.mkdir(feature_path)
      additional_file = Tempfile.new(['additional', '.yml'], feature_path)
      additional_file.write(YAML.dump(additional))
      additional_file.close

      status_seed = MiqProductFeature.seed_features(feature_path)
      expect(MiqProductFeature.count).to eq(3)
      expect(status_seed[:created]).to match_array %w(everything dialog_new_editor dialog_edit_editor)

      additional_file.unlink
      Dir.rmdir(feature_path)
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

        let!(:tenant) { FactoryGirl.create(:tenant, :parent => root_tenant) }

        before do
          MiqProductFeature.seed_features(feature_path)
        end

        it "creates tenant features" do
          features = miq_product_feature_class.tenant_features_in_hash
          expect(features).to match_array([{ "name" => "Edit (#{root_tenant.name})", "description" => "XXX for tenant #{root_tenant.name}",
                                               "identifier" => "dialog_copy_editor_tenant_#{root_tenant.id}", "tenant_id" => root_tenant.id},
                                           {"name" => "Edit (#{tenant.name})", "description" => "XXX for tenant #{tenant.name}",
                                            "identifier" => "dialog_copy_editor_tenant_#{tenant.id}", "tenant_id" => tenant.id}])

          expect(MiqProductFeature.where(:identifier => "dialog_copy_editor", :name => "Edit").count).to eq(1)
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
      f1 = FactoryGirl.create(:miq_product_feature, :identifier => "f1", :name => "F1n")
      FactoryGirl.create(:miq_product_feature, :identifier => "f2", :name => "F2n", :parent_id => f1.id)
      f3 = FactoryGirl.create(:miq_product_feature, :identifier => "f3", :name => "F3n", :parent_id => f1.id)
      FactoryGirl.create(:miq_product_feature, :identifier => "f4", :name => "F4n", :parent_id => f3.id)
      FactoryGirl.create(:miq_product_feature, :identifier => "f5", :name => "F5n", :parent_id => f3.id)

      expect { MiqProductFeature.features }.to match_query_limit_of(1)
      expect { MiqProductFeature.features }.to match_query_limit_of(0)

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
    let!(:f0) { FactoryGirl.create(:miq_product_feature, :identifier => "everything", :name => "F0n") }
    let!(:f1) { FactoryGirl.create(:miq_product_feature, :identifier => "f1", :name => "F1n", :parent_id => f0.id) }
    let!(:f2) { FactoryGirl.create(:miq_product_feature, :identifier => "f2", :name => "F2n", :parent_id => f1.id) }
    let!(:f3) { FactoryGirl.create(:miq_product_feature, :identifier => "f3", :name => "F3n", :parent_id => f1.id) }
    let!(:f4) { FactoryGirl.create(:miq_product_feature, :identifier => "f4", :name => "F4n", :parent_id => f3.id) }
    let!(:f5) { FactoryGirl.create(:miq_product_feature, :identifier => "f5", :name => "F5n", :parent_id => f3.id) }

    it "memoizes hash to prevent extra db queries" do
      expect { MiqProductFeature.obj_features }.to match_query_limit_of(1)
      expect { MiqProductFeature.obj_features }.to match_query_limit_of(0)
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
