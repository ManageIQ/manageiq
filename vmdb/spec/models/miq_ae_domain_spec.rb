require "spec_helper"

describe MiqAeDomain do
  it "should use the highest priority when not specified" do
    MiqAeDomain.create(:name => 'TEST1')
    MiqAeDomain.create(:name => 'TEST2', :priority => 10)
    d3 = MiqAeDomain.create(:name => 'TEST3')
    d3.priority.should eql(11)
  end

  context "reset priority" do
    before do
      initial = {'TEST1' => 11, 'TEST2' => 12, 'TEST3' => 13, 'TEST4' => 14}
      initial.each { |dom, pri| MiqAeDomain.create(:name => dom, :priority => pri) }
    end

    it "should change priority based on ordered list of ids" do
      after = {'TEST4' => 1, 'TEST3' => 2, 'TEST2' => 3, 'TEST1' => 4}
      ids   = after.collect { |dom, _| MiqAeDomain.find_by_fqname(dom).id }
      MiqAeDomain.reset_priority_by_ordered_ids(ids)
      after.each { |dom, pri| MiqAeDomain.find_by_fqname(dom).priority.should eql(pri) }
    end

    it "after a domain with lowest priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST1').id)
      after = {'TEST2' => 1, 'TEST3' => 2, 'TEST4' => 3}
      after.each { |dom, pri| MiqAeDomain.find_by_fqname(dom).priority.should eql(pri) }
    end

    it "after a domain with middle priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST3').id)
      after = {'TEST1' => 1, 'TEST2' => 2, 'TEST4' => 3}
      after.each { |dom, pri| MiqAeDomain.find_by_fqname(dom).priority.should eql(pri) }
    end

    it "after a domain with highest priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST4').id)
      after = {'TEST1' => 1, 'TEST2' => 2, 'TEST3' => 3}
      after.each { |dom, pri| MiqAeDomain.find_by_fqname(dom).priority.should eql(pri) }
    end

    it "after all domains are deleted" do
      %w(TEST1 TEST2 TEST3 TEST4).each { |name| MiqAeDomain.find_by_fqname(name).destroy }
      d1 = MiqAeDomain.create(:name => 'TEST1')
      d1.priority.should eql(1)
    end
  end

  context "any_unlocked?" do
    it "should return unlocked_domains? as true if the there are any unlocked domains available" do
      FactoryGirl.create(:miq_ae_namespace, :name => 'd1', :priority => 10, :system => true)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd2', :priority => 10, :system => false)
      MiqAeDomain.any_unlocked?.should be_true
    end

    it "should return unlocked_domains? as false if the there are no unlocked domains available" do
      FactoryGirl.create(:miq_ae_namespace, :name => 'd1', :priority => 10, :system => true)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd2', :priority => 10, :system => true)
      MiqAeDomain.any_unlocked?.should be_false
    end
  end

  context "all_unlocked" do
    it "should return all unlocked domains" do
      FactoryGirl.create(:miq_ae_namespace, :name => 'd1', :priority => 10, :system => true)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd2', :priority => 10, :system => false)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd3', :priority => 10, :system => nil)
      MiqAeDomain.all_unlocked.count.should eq(2)
    end

    it "should return empty array when there are no unlocked domains" do
      FactoryGirl.create(:miq_ae_namespace, :name => 'd1', :priority => 10, :system => true)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd2', :priority => 10, :system => true)
      FactoryGirl.create(:miq_ae_namespace, :name => 'd3', :priority => 10, :system => true)
      MiqAeDomain.all_unlocked.count.should eq(0)
    end
  end

  context "same class names across domains" do
    before(:each) do
      create_model(:name => 'DOM1', :priority => 10)
    end

    it "missing class should get empty array" do
      result = MiqAeClass.get_homonymic_across_domains('DOM1/CLASS1')
      result.should be_empty
    end

    it "get same named classes" do
      create_multiple_domains
      expected = %w(DOM2/A/b/C/cLaSS1 DOM1/A/B/C/CLASS1 DOM3/a/B/c/CLASs1)
      result = MiqAeClass.get_homonymic_across_domains('/DOM1/A/B/C/CLASS1', true)
      expected.should match_array(result.each.collect(&:fqname))
    end
  end

  context "same instance names across domains" do
    before(:each) do
      create_model(:name => 'DOM1', :priority => 10)
    end

    it "missing instance should get empty array" do
      result = MiqAeInstance.get_homonymic_across_domains('DOM1/CLASS1/nothing')
      result.should be_empty
    end

    it "get same named instances" do
      create_multiple_domains
      expected = %w(
        DOM5/A/B/C/CLASS1/instance1
        DOM2/A/b/C/cLaSS1/instance1
        DOM1/A/B/C/CLASS1/instance1
        DOM3/a/B/c/CLASs1/instance1
      )
      result = MiqAeInstance.get_homonymic_across_domains('/DOM1/A/B/C/CLASS1/instance1')
      expected.should match_array(result.each.collect(&:fqname))
    end
  end

  context "same method names across domains" do
    before(:each) do
      create_model_with_methods(:name => 'DOM1', :priority => 10)
    end

    it "missing method should get empty array" do
      result = MiqAeMethod.get_homonymic_across_domains('DOM1/CLASS1/nothing')
      result.should be_empty
    end

    it "get same named methods" do
      create_multiple_domains_with_methods
      expected = %w(DOM2/A/b/C/cLaSS1/method1 DOM1/A/B/C/CLASS1/method1 DOM3/a/B/c/CLASs1/method1)
      result = MiqAeMethod.get_homonymic_across_domains('/DOM1/A/B/C/CLASS1/method1', true)
      expected.should match_array(result.each.collect(&:fqname))
    end
  end

  def create_model(attrs = {})
    attrs = default_attributes(attrs)
    ae_fields = {'field1' => {:aetype => 'relationship', :datatype => 'string'}}
    ae_instances = {'instance1' => {'field1' => {:value => 'hello world'}}}

    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_instances,
                       attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
  end

  def create_model_with_methods(attrs = {})
    attrs = default_attributes(attrs)
    ae_methods = {'method1' => {:scope => 'instance', :location => 'inline',
                                :data => 'puts "Hello World"',
                                :language => 'ruby', 'params' => {}}}
    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_methods,
                       attrs.merge('ae_methods' => ae_methods))
  end

  def create_multiple_domains
    create_model(:name => 'DOM2', :priority => 20, :ae_class => 'cLaSS1',
                 :ae_namespace => 'A/b/C')
    create_model(:name => 'DOM3', :priority => 5, :ae_class => 'CLASs1',
                 :ae_namespace => 'a/B/c')
    create_model(:name => 'DOM4', :priority => 2, :ae_class => 'CLASs1',
                 :ae_namespace => 'a/B')
    create_model(:name => 'DOM5', :priority => 50, :enabled => false)
  end

  def create_multiple_domains_with_methods
    create_model_with_methods(:name => 'DOM2', :priority => 20, :ae_class => 'cLaSS1',
                              :ae_namespace => 'A/b/C')
    create_model_with_methods(:name => 'DOM3', :priority => 5, :ae_class => 'CLASs1',
                              :ae_namespace => 'a/B/c')
    create_model_with_methods(:name => 'DOM4', :priority => 2, :ae_class => 'CLASs1',
                              :ae_namespace => 'a/B')
    create_model_with_methods(:name => 'DOM5', :priority => 50, :enabled => false)
  end

  def default_attributes(attrs = {})
    attrs[:ae_class] = 'CLASS1' unless attrs.key?(:ae_class)
    attrs[:ae_namespace] = 'A/B/C' unless attrs.key?(:ae_namespace)
    attrs[:priority] = 10 unless attrs.key?(:priority)
    attrs[:enabled] = true unless attrs.key?(:enabled)
    attrs
  end

end
