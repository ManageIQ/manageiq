require "spec_helper"

describe RelationshipMixin do
  TEST_REL_TYPE = "testing"

  #      0
  #  1        2
  # 3 4    5  6  7
  #             8 9
  VMS_REL_TREE = {0 => [{1 => [3, 4]}, {2 => [5, 6, {7 => [8, 9]}]}]}

  context "tree with relationship type '#{TEST_REL_TYPE}'" do
    before(:each) do
      @vms = (0...10).collect { FactoryGirl.create(:vm_vmware) }
      self.build_relationship_tree(VMS_REL_TREE, @vms)
    end

    it "#with_relationship_type and #relationship_type" do
      @vms[0].relationship_type.should_not == TEST_REL_TYPE
      @vms[0].with_relationship_type(TEST_REL_TYPE) do
        @vms[0].relationship_type.should == TEST_REL_TYPE
      end

      @vms[0].parents.should be_empty
      @vms[0].children.should be_empty

      @vms[0].clear_relationships_cache

      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.parents.length  }.should == 0
      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.children.length }.should == 2

      @vms[0].parents.should be_empty
      @vms[0].children.should be_empty
    end

    it "#parents" do
      @vms[0].parents.should be_empty
      recurse_relationship_tree(VMS_REL_TREE) do |parent, child|
        @vms[child].with_relationship_type(TEST_REL_TYPE) do |c|
          c.parents.should == [@vms[parent]]
        end
      end
    end

    it "#children" do
      recurse_relationship_tree(VMS_REL_TREE) do |parent, child|
        @vms[parent].with_relationship_type(TEST_REL_TYPE) do |p|
          p.children.should include @vms[child]
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
        @parent.with_relationship_type(TEST_REL_TYPE) { |v| v.set_child(child) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], []
        )
      end

      it "with a root object will link a new tree node for the parent to the existing tree node for the child" do
        child = @vms[0]
        @parent.with_relationship_type(TEST_REL_TYPE) { |v| v.set_child(child) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], [@vms[1], @vms[2]]
        )
      end

      it "with an inner object will link a new tree node for the parent to a second new tree node for the child" do
        child = @vms[1]
        @parent.with_relationship_type(TEST_REL_TYPE) { |v| v.set_child(child) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   2, [@vms[0], @parent], [@vms[3], @vms[4]]
        )
      end

      it "with a leaf object will link a new tree node for the parent to a second new tree node for the child" do
        child = @vms[3]
        @parent.with_relationship_type(TEST_REL_TYPE) { |v| v.set_child(child) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   2, [@vms[1], @parent], []
        )
      end
    end

    context "#set_parent on a new child object" do
      before(:each) { @child = FactoryGirl.create(:vm_vmware) }

      it "with a second new object will link a new tree node for the parent to a new tree node for the child" do
        parent = FactoryGirl.create(:vm_vmware)
        @child.with_relationship_type(TEST_REL_TYPE) { |v| v.set_parent(parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          parent, 1, [], [@child],
          @child, 1, [parent], []
        )
      end

      it "with a root object will link the existing tree node for the parent to a new tree node for the child" do
        parent = @vms[0]
        @child.with_relationship_type(TEST_REL_TYPE) { |v| v.set_parent(parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          parent, 1, [], [@vms[1], @vms[2], @child],
          @child, 1, [parent], []
        )
      end

      it "with an inner object will link the existing tree node for the parent to a new tree node for the child" do
        parent = @vms[1]
        @child.with_relationship_type(TEST_REL_TYPE) { |v| v.set_parent(parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          parent, 1, [@vms[0]], [@vms[3], @vms[4], @child],
          @child, 1, [parent], []
        )
      end

      it "with a leaf object will link the existing tree node for the parent to a new tree node for the child" do
        parent = @vms[3]
        @child.with_relationship_type(TEST_REL_TYPE) { |v| v.set_parent(parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          parent, 1, [@vms[1]], [@child],
          @child, 1, [parent], []
        )
      end
    end

    context "with a new parent object, #replace_parent" do
      before(:each) { @parent = FactoryGirl.create(:vm_vmware) }

      it "on a second new object will link a new tree node for the parent to a new tree node for the child and be the only parent for the child" do
        child = FactoryGirl.create(:vm_vmware)
        child.with_relationship_type(TEST_REL_TYPE) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], []
        )
      end

      it "on a root object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = @vms[0]
        child.with_relationship_type(TEST_REL_TYPE) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], [@vms[1], @vms[2]]
        )
      end

      it "on an inner object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = @vms[1]
        child.with_relationship_type(TEST_REL_TYPE) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], [@vms[3], @vms[4]]
        )
      end

      it "on a leaf object will link a new tree node for the parent to the existing tree node for the child and be the only parent for the child" do
        child = @vms[3]
        child.with_relationship_type(TEST_REL_TYPE) { |v| v.replace_parent(@parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          @parent, 1, [], [child],
          child,   1, [@parent], []
        )
      end
    end

    context "#replace_parent on an inner object" do
      it "with another inner object will link the existing tree node for the parent to the existing tree node for the child and be the only parent for the child " do
        parent = @vms[1]
        child = @vms[2]
        child.with_relationship_type(TEST_REL_TYPE) { |v| v.replace_parent(parent) }

        assert_parent_child_structure(TEST_REL_TYPE,
          parent, 1, [@vms[0]], [child, @vms[3], @vms[4]],
          child,  1, [parent], [@vms[5], @vms[6], @vms[7]]
        )
      end
    end

    it "#replace_children" do
      new_vms = (0...2).collect { FactoryGirl.create(:vm_vmware) }
      @vms[0].with_relationship_type(TEST_REL_TYPE) do |v|
        v.replace_children(new_vms)
        new_vms.should match_array(v.children)
      end

      @vms[1].with_relationship_type(TEST_REL_TYPE) do |v|
        v.parents.should be_empty
      end
    end

    it "#remove_all_parents" do
      @vms[1].with_relationship_type(TEST_REL_TYPE) do |v|
        v.remove_all_parents
        v.parents.should be_empty
      end
    end

    it "#remove_all_children" do
      @vms[1].with_relationship_type(TEST_REL_TYPE) do |v|
        v.remove_all_children
        v.children.should be_empty
      end
    end

    it "#remove_all_relationships" do
      @vms[1].with_relationship_type(TEST_REL_TYPE) do |v|
        v.remove_all_relationships
        v.parents.should be_empty
        v.children.should be_empty
      end
    end

    it "#is_descendant_of?" do
      @vms[1].with_relationship_type(TEST_REL_TYPE) { |v| v.is_descendant_of?(@vms[0]) }.should be_true
      @vms[3].with_relationship_type(TEST_REL_TYPE) { |v| v.is_descendant_of?(@vms[0]) }.should be_true
      @vms[2].with_relationship_type(TEST_REL_TYPE) { |v| v.is_descendant_of?(@vms[1]) }.should_not be_true
    end

    it "#is_ancestor_of?" do
      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.is_ancestor_of?(@vms[1]) }.should be_true
      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.is_ancestor_of?(@vms[3]) }.should be_true
      @vms[2].with_relationship_type(TEST_REL_TYPE) { |v| v.is_ancestor_of?(@vms[1]) }.should_not be_true
    end

    it "#ancestors" do
      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.ancestors.empty? }.should be_true
      @vms[9].with_relationship_type(TEST_REL_TYPE) { |v| v.ancestors }.should match_array([@vms[7], @vms[2], @vms[0]])
    end

    it "#descendants" do
      @vms[9].with_relationship_type(TEST_REL_TYPE) { |v| v.descendants.empty? }.should be_true
      @vms[0].with_relationship_type(TEST_REL_TYPE) { |v| v.descendants }.should match_array(@vms - [@vms[0]])
    end
  end

  context "tree with no relationships" do
    before(:each) { @host = FactoryGirl.create(:host) }

    it('#root') { @host.root.should == @host }

    it('#ancestors')   { @host.ancestors.should   == [] }
    it('#path')        { @host.path.should        == [@host] }
    it('#descendants') { @host.descendants.should == [] }
    it('#subtree')     { @host.subtree.should     == [@host] }
    it('#fulltree')    { @host.fulltree.should    == [@host] }

    it('#descendants_arranged') { @host.descendants_arranged.should == {} }
    it('#subtree_arranged')     { @host.subtree_arranged.should     == {@host => {}} }
    it('#fulltree_arranged')    { @host.fulltree_arranged.should    == {@host => {}} }
  end

  context "tree with relationship type 'ems_metadata'" do
    before(:each) do
      @vms = (0...10).collect { FactoryGirl.create(:vm_vmware) }
      self.build_relationship_tree(VMS_REL_TREE, @vms, "ems_metadata")
    end

    it "#detect_ancestor" do
      @vms[8].with_relationship_type("ems_metadata") { |v| v.detect_ancestor { |a| a.id == @vms[2].id } }.should_not be_nil
      @vms[8].with_relationship_type("ems_metadata") { |v| v.detect_ancestor { |a| a.id == @vms[1].id } }.should be_nil
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
      @ws.members.length.should == 1
    end

    it "of a method without arguments" do
      @ws.members.length.should == 2
    end
  end

  protected

  def build_relationship_tree(tree, objs, rel_type = TEST_REL_TYPE)
    rels = objs.collect { |o| FactoryGirl.create(:relationship_vm_vmware, :resource_id => o.id, :relationship => rel_type) }
    recurse_relationship_tree(tree) do |parent, child|
      rels[child].parent = rels[parent]
      rels[child].save!
    end
    objs.each { |o| o.unmemoize_all }
  end

  def recurse_relationship_tree(tree, &block)
    parent   = tree.keys.first
    children = tree[parent]
    children = children.collect { |child| child.kind_of?(Hash) ? self.recurse_relationship_tree(child, &block) : child }
    children.each { |child| yield parent, child }
    return parent
  end

  def assert_parent_child_structure(rel_type, parent, p_rels_count, p_parents, p_children, child, c_rels_count, c_parents, c_children)
    parent.with_relationship_type(rel_type) do
      parent.relationships.length.should == p_rels_count
      parent.parents.length.should       == p_parents.length
      parent.parents.should              match_array(p_parents)
      parent.children.length.should      == p_children.length
      parent.children.should             match_array(p_children)
    end

    child.with_relationship_type(rel_type) do
      child.relationships.length.should == c_rels_count
      child.parents.length.should       == c_parents.length
      child.parents.should              match_array(c_parents)
      child.children.length.should      == c_children.length
      child.children.should             match_array(c_children)
    end
  end
end
