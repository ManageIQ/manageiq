describe TreeBuilderOpsRbacMenu do
  let(:features) do
    %w{
      all_vm_rules
      instance
      instance_view
      instance_show_list
      instance_control
      instance_scan
    }
  end

  let(:cid) { ApplicationRecord.uncompress_id("10r2") }

  let(:role) do
    FactoryGirl.create(:miq_user_role, :id => cid, :features => features)
  end

  let(:tree) do
    TreeBuilderOpsRbacMenu.new(
      "features_tree",
      "features",
      {},
      true,
      role: role,
      editable: false
    )
  end

  let(:main_keys) { bs_tree.first["nodes"].map{|n| n['key']} }

  describe 'bs_tree' do
    subject(:bs_tree) { JSON.parse(tree.locals_for_render[:bs_tree]) }

    it 'builds the bs_tree' do
      t = bs_tree.first

      expect(t['key']).to match(/all_vm_rules/)
      expect(t['title']).to be_nil
      expect(t['tooltip']).to be_nil
      expect(t['checkable']).to eq(false)
    end
    #
    it 'includes main sections' do
      expect(main_keys).to include("xx-10r2___tab_aut")
      expect(main_keys).to include("xx-10r2___tab_compute")
      expect(main_keys).to include("xx-10r2___tab_con")
      expect(main_keys).to include("xx-10r2___tab_conf")
      expect(main_keys).to include("xx-10r2___tab_mdl")
      expect(main_keys).to include("xx-10r2___tab_net")
      expect(main_keys).to include("xx-10r2___tab_opt")
      expect(main_keys).to include("xx-10r2___tab_set")
      expect(main_keys).to include("xx-10r2___tab_sto")
      expect(main_keys).to include("xx-10r2___tab_svc")
      expect(main_keys).to include("xx-10r2___tab_vi")
    end

    it 'does not include blank nodes' do
      expect(main_keys).not_to include("xx-10r2__")
      expect(main_keys).not_to include("xx-10r2___tab_")
    end
  end
end
