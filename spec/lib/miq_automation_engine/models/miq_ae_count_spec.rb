require 'spec_helper'

describe MiqAeDatastore do
  before do
    dom = MiqAeDomain.create(:name => 'ABC', :enabled => true)
    ns  = MiqAeNamespace.create(:name => 'NS1', :parent_id => dom.id)
    class_and_children(ns, 'KLASS1', 'INST1', 'METH1')
    class_and_children(ns, 'KLASS2', 'INST1', 'METH1')
    MiqAeDomain.create(:name => 'ABC123', :enabled => true)
  end

  def class_and_children(ns, klass_name, instance_name, method_name)
    cls = MiqAeClass.create(:name => klass_name, :namespace_id => ns.id, :description => 'A Class')
    MiqAeInstance.create(:name => instance_name, :class_id => cls.id)
    MiqAeMethod.create(:name => method_name, :class_id => cls.id, :location => 'inline',
                              :scope => 'instance', :language => 'ruby', :data => 'puts 1')
  end

  it 'compare instance count' do
    MiqAeInstance.count.should  == 2
  end

  it 'compare method count' do
    MiqAeMethod.count.should  == 2
  end

  it 'compare class count' do
    MiqAeClass.count.should  == 2
  end

  it 'compare namespace count' do
    MiqAeNamespace.count.should  == 1
  end

  it 'compare domain count' do
    MiqAeDomain.count.should  == 2
  end
end
