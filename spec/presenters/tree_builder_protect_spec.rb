describe TreeBuilderProtect do
  context 'TreeBuilderProtect' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Select Policy Profiles")
      login_as FactoryGirl.create(:user, :userid => 'policy_profile_wilma', :miq_groups => [@group])
      policy1 = FactoryGirl.create(:miq_policy, :mode => 'something')
      set1 = FactoryGirl.create(:miq_policy_set, :description => 'first')
      set1.add_member(policy1)
      set1.save!
      allow(set1).to receive(:active).and_return(true)
      allow(set1).to receive(:members).and_return([policy1])
      set2 = FactoryGirl.create(:miq_policy_set, :description => 'second')
      allow(set2).to receive(:active).and_return(true)
      set3 = FactoryGirl.create(:miq_policy_set, :description => 'third')
      allow(set3).to receive(:active).and_return(false)
      @roots = [set1, set2, set3].sort_by! { |profile| profile.description.downcase }
      @kids = [policy1]
      @edit = {:controller_name => 'name'}
      @edit[:new] = @edit[:current] = {set1[:id] => 1}
      @edit[:pol_items] = [101]
      @protect_tree = TreeBuilderProtect.new(:protect, :protect_tree, {}, true, @edit)
    end

    it 'set init options correctly' do
      tree_options = @protect_tree.send(:tree_init_options, :protect)
      expect(tree_options).to eq(:full_ids => false, :add_root => false, :lazy => false)
    end

    it 'set locals for render correctly' do
      locals = @protect_tree.send(:set_locals_for_render)
      expect(locals[:oncheck]).to eq("miqOnCheckProtect")
      expect(locals[:checkboxes]).to eq(true)
      expect(locals[:check_url]).to eq("/name/protect/")
    end

    it 'sets roots correctly' do
      roots = @protect_tree.send(:x_get_tree_roots, false)
      @roots.each_with_index do |root, i|
        expect(roots[i][:id]).to eq("policy_profile_#{root.id}")
        expect(roots[i][:image]).to eq("100/policy_profile#{root.active? ? "" : "_inactive"}.png")
        expect(roots[i][:text]).to eq(root.description)
        expect(roots[i][:children]).to eq(root.members)
        expect(roots[i][:select]).to eq(@edit[:new].keys.include?(root.id))
      end
      expect(roots.size).to eq(3)
    end

    it 'sets Policy ' do
      roots = @protect_tree.send(:x_get_tree_roots, false)
      kids = @protect_tree.send(:x_get_tree_hash_kids, roots[0], false)
      expect(kids[0][:id]).to eq("policy_#{@kids[0].id}")
      expect(kids[0][:text]).to eq("<b>#{ui_lookup(:model => @kids[0].towhat)} #{@kids[0].mode.capitalize}:</b> #{@kids[0].description}".html_safe)
      expect(kids[0][:image]).to eq("100/miq_policy_#{@kids[0].towhat.downcase}#{@kids[0].active ? "" : "_inactive"}.png")
      expect(kids[0][:tip]).to eq(@kids[0].description)
      expect(kids[0][:hideCheckbox]).to eq(true)
      expect(kids[0][:children]).to eq([])
    end
  end
end
