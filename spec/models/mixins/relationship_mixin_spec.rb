describe RelationshipMixin do
  let(:test_rel_type) { "testing" }
  #      0
  #  1        2
  # 3 4    5  6  7
  #             8 9
  let(:vms_rel_tree) { {0 => [{1 => [3, 4]}, {2 => [5, 6, {7 => [8, 9]}]}]} }
  let(:vms) { build_relationship_tree(vms_rel_tree) }

  context "tree with relationship" do
    it "#with_relationship_type and #relationship_type" do
      expect(vms[0].relationship_type).not_to eq(test_rel_type)
      vms[0].with_relationship_type(test_rel_type) do
        expect(vms[0].relationship_type).to eq(test_rel_type)
      end

      expect(vms[0].parents).to be_empty
      expect(vms[0].children).to be_empty

      vms[0].clear_relationships_cache

      expect(vms[0].with_relationship_type(test_rel_type) { |v| v.parents.length  }).to eq(0)
      expect(vms[0].with_relationship_type(test_rel_type) { |v| v.children.length }).to eq(2)

      expect(vms[0].parents).to be_empty
      expect(vms[0].children).to be_empty
    end

    it "#parents" do
      expect(vms[0].parents).to be_empty
      recurse_relationship_tree(vms_rel_tree) do |parent, child|
        vms[child].with_relationship_type(test_rel_type) do |c|
          expect(c.parents).to eq([vms[parent]])
        end
      end
    end

    it "#children" do
      recurse_relationship_tree(vms_rel_tree) do |parent, child|
        vms[parent].with_relationship_type(test_rel_type) do |p|
          expect(p.children).to include vms[child]
        end
      end
    end

    # NOTE for understanding the next 4 contexts:
    # Objects (VMs, Hosts, etc) have associated tree nodes entries in the
    # relationships table which are linked.  If an object must reside in
    # multiple parts of the tree via having multiple parents, it will need more
    # than one associated tree node.

    context "#set_child on a new parent object" do
      before(:each) { @parent = FactoryGirl.create(:vm_vmware) }

      it "with a second new object will link a new tree node for the parent to a new tree node for the child" do
        child = FactoryGirl.create(:vm_vmware)
        @parent.with_relationship_type(test_rel_type) { |v| v.set_child(child) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], []
                                     )
      end

      it "with a root object will link a new tree node for the parent to the existing tree node for the child" do
        child = vms[0]
        @parent.with_relationship_type(test_rel_type) { |v| v.set_child(child) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], [vms[1], vms[2]]
                                     )
      end

      it "with an inner object will link a new tree node for the parent to a second new tree node for the child" do
        child = vms[1]
        @parent.with_relationship_type(test_rel_type) { |v| v.set_child(child) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   2, [vms[0], @parent], [vms[3], vms[4]]
                                     )
      end

      it "with a leaf object will link a new tree node for the parent to a second new tree node for the child" do
        child = vms[3]
        @parent.with_relationship_type(test_rel_type) { |v| v.set_child(child) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   2, [vms[1], @parent], []
                                     )
      end
    end

    context "#set_parent on a new child object" do
      before(:each) { @child = FactoryGirl.create(:vm_vmware) }

      it "with a second new object will link a new tree node for the parent to a new tree node for the child" do
        parent = FactoryGirl.create(:vm_vmware)
        @child.with_relationship_type(test_rel_type) { |v| v.set_parent(parent) }

        assert_parent_child_structure(test_rel_type,
                                      parent, 1, [], [@child],
                                      @child, 1, [parent], []
                                     )
      end

      it "with a root object will link the existing tree node for the parent to a new tree node for the child" do
        parent = vms[0]
        @child.with_relationship_type(test_rel_type) { |v| v.set_parent(parent) }

        assert_parent_child_structure(test_rel_type,
                                      parent, 1, [], [vms[1], vms[2], @child],
                                      @child, 1, [parent], []
                                     )
      end

      it "with an inner object will link the existing tree node for the parent to a new tree node for the child" do
        parent = vms[1]
        @child.with_relationship_type(test_rel_type) { |v| v.set_parent(parent) }

        assert_parent_child_structure(test_rel_type,
                                      parent, 1, [vms[0]], [vms[3], vms[4], @child],
                                      @child, 1, [parent], []
                                     )
      end

      it "with a leaf object will link the existing tree node for the parent to a new tree node for the child" do
        parent = vms[3]
        @child.with_relationship_type(test_rel_type) { |v| v.set_parent(parent) }

        assert_parent_child_structure(test_rel_type,
                                      parent, 1, [vms[1]], [@child],
                                      @child, 1, [parent], []
                                     )
      end
    end

    context "with a new parent object, #replace_parent" do
      before(:each) { @parent = FactoryGirl.create(:vm_vmware) }

      it "on a second new object will link a new tree node for the parent to a new tree node for the child and be the only parent for the child" do
        child = FactoryGirl.create(:vm_vmware)
        child.with_relationship_type(test_rel_type) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], []
                                     )
      end

      it "on a root object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = vms[0]
        child.with_relationship_type(test_rel_type) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], [vms[1], vms[2]]
                                     )
      end

      it "on an inner object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = vms[1]
        child.with_relationship_type(test_rel_type) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], [vms[3], vms[4]]
                                     )
      end

      it "on a leaf object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = vms[3]
        child.with_relationship_type(test_rel_type) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(test_rel_type,
                                      @parent, 1, [], [child],
                                      child,   1, [@parent], []
                                     )
      end
    end

    context "#replace_parent on an inner object" do
      it "with another inner object will link the existing tree node for the parent to the existing tree node for the child and be the only parent for the child " do
        parent = vms[1]
        child = vms[2]
        child.with_relationship_type(test_rel_type) { |v| v.replace_parent(parent) }

        assert_parent_child_structure(test_rel_type,
                                      parent, 1, [vms[0]], [child, vms[3], vms[4]],
                                      child,  1, [parent], [vms[5], vms[6], vms[7]]
                                     )
      end
    end

    it "#replace_children" do
      new_vms = (0...2).collect { FactoryGirl.create(:vm_vmware) }
      vms[0].with_relationship_type(test_rel_type) do |v|
        v.replace_children(new_vms)
        expect(new_vms).to match_array(v.children)
      end

      vms[1].with_relationship_type(test_rel_type) do |v|
        expect(v.parents).to be_empty
      end
    end

    it "#remove_all_parents" do
      vms[1].with_relationship_type(test_rel_type) do |v|
        v.remove_all_parents
        expect(v.parents).to be_empty
      end
    end

    it "#remove_all_children" do
      vms[1].with_relationship_type(test_rel_type) do |v|
        v.remove_all_children
        expect(v.children).to be_empty
      end
    end

    it "#remove_all_relationships" do
      vms[1].with_relationship_type(test_rel_type) do |v|
        v.remove_all_relationships
        expect(v.parents).to be_empty
        expect(v.children).to be_empty
      end
    end

    it "#is_descendant_of?" do
      expect(vms[1].with_relationship_type(test_rel_type) { |v| v.is_descendant_of?(vms[0]) }).to be_truthy
      expect(vms[3].with_relationship_type(test_rel_type) { |v| v.is_descendant_of?(vms[0]) }).to be_truthy
      expect(vms[2].with_relationship_type(test_rel_type) { |v| v.is_descendant_of?(vms[1]) }).not_to be_truthy
    end

    it "#is_ancestor_of?" do
      expect(vms[0].with_relationship_type(test_rel_type) { |v| v.is_ancestor_of?(vms[1]) }).to be_truthy
      expect(vms[0].with_relationship_type(test_rel_type) { |v| v.is_ancestor_of?(vms[3]) }).to be_truthy
      expect(vms[2].with_relationship_type(test_rel_type) { |v| v.is_ancestor_of?(vms[1]) }).not_to be_truthy
    end

    it "#ancestors" do
      expect(vms[0].with_relationship_type(test_rel_type) { |v| v.ancestors.empty? }).to be_truthy
      expect(vms[9].with_relationship_type(test_rel_type, &:ancestors)).to match_array([vms[7], vms[2], vms[0]])
    end

    it "#descendants" do
      expect(vms[9].with_relationship_type(test_rel_type) { |v| v.descendants.empty? }).to be_truthy
      expect(vms[0].with_relationship_type(test_rel_type, &:descendants)).to match_array(vms.values - [vms[0]])
    end
  end

  context "tree with no relationships" do
    before(:each) { @host = FactoryGirl.create(:host) }

    it('#root') { expect(@host.root).to eq(@host) }

    it('#ancestors')   { expect(@host.ancestors).to eq([]) }
    it('#path')        { expect(@host.path).to eq([@host]) }
    it('#descendants') { expect(@host.descendants).to eq([]) }
    it('#subtree')     { expect(@host.subtree).to eq([@host]) }
    it('#fulltree')    { expect(@host.fulltree).to eq([@host]) }

    it('#descendants_arranged') { expect(@host.descendants_arranged).to eq({}) }
    it('#subtree_arranged')     { expect(@host.subtree_arranged).to eq({@host => {}}) }
    it('#fulltree_arranged')    { expect(@host.fulltree_arranged).to eq({@host => {}}) }
  end

  context "tree with relationship type 'ems_metadata'" do
    let(:vms) { build_relationship_tree(vms_rel_tree, "ems_metadata") }

    it "#detect_ancestor" do
      expect(vms[8].with_relationship_type("ems_metadata") { |v| v.detect_ancestor { |a| a.id == vms[2].id } }).not_to be_nil
      expect(vms[8].with_relationship_type("ems_metadata") { |v| v.detect_ancestor { |a| a.id == vms[1].id } }).to be_nil
    end
  end

  context ".alias_with_relationship_type" do
    before(:each) do
      @ws = FactoryGirl.create(:miq_widget_set)
      @w1 = FactoryGirl.create(:miq_widget)
      @w2 = FactoryGirl.create(:miq_widget)
      @ws.add_member(@w1)
      @ws.add_member(@w2)
    end

    it "of a method with arguments" do
      @ws.remove_member(@w1)
      expect(@ws.members.length).to eq(1)
    end

    it "of a method without arguments" do
      expect(@ws.members.length).to eq(2)
    end
  end

  protected

  def build_relationship_tree(tree, rel_type = test_rel_type)
    # temp list of the relationships
    # allows easy access while building
    # can map to the resource to return all the resources created
    rels = Hash.new do |hash, key|
      hash[key] = FactoryGirl.create(:relationship_vm_vmware,
                                     :resource     => FactoryGirl.create(:vm_vmware),
                                     :relationship => rel_type)
    end

    recurse_relationship_tree(tree) do |parent, child|
      rels[child].parent = rels[parent]
      rels[child].save!
    end
    # pull out all values in key order. (0, 1, 2, 3, ...) (unmemoize them on the way out)
    rels.each_with_object({}) { |(n, v), h| h[n] = v.resource.tap(&:unmemoize_all) }
  end

  def recurse_relationship_tree(tree, &block)
    parent   = tree.keys.first
    children = tree[parent]
    children = children.collect { |child| child.kind_of?(Hash) ? recurse_relationship_tree(child, &block) : child }
    children.each { |child| yield parent, child }
    parent
  end

  def assert_parent_child_structure(rel_type, parent, p_rels_count, p_parents, p_children, child, c_rels_count, c_parents, c_children)
    parent.with_relationship_type(rel_type) do
      expect(parent.relationships.length).to eq(p_rels_count)
      expect(parent.parents.length).to eq(p_parents.length)
      expect(parent.parents).to              match_array(p_parents)
      expect(parent.children.length).to eq(p_children.length)
      expect(parent.children).to             match_array(p_children)
    end

    child.with_relationship_type(rel_type) do
      expect(child.relationships.length).to eq(c_rels_count)
      expect(child.parents.length).to eq(c_parents.length)
      expect(child.parents).to              match_array(c_parents)
      expect(child.children.length).to eq(c_children.length)
      expect(child.children).to             match_array(c_children)
    end
  end
end
