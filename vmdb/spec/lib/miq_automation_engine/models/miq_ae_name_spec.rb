require 'spec_helper'

describe MiqAeDatastore do
  before do
    @dom = MiqAeDomain.create(:name => 'ABC', :enabled => true)
    @ns  = MiqAeNamespace.create(:name => 'NS1', :parent_id => @dom.id)
    class_and_children(@ns, 'KLASS1', 'INST1', 'METH1')
    class_and_children(@ns, 'KLASS2', 'INST1', 'METH1')
  end

  def class_and_children(ns, klass_name, instance_name, method_name)
    cls = MiqAeClass.create(:name => klass_name, :namespace_id => ns.id, :description => 'A Class')
    MiqAeInstance.create(:name => instance_name, :class_id => cls.id)
    MiqAeMethod.create(:name => method_name, :class_id => cls.id, :location => 'inline',
                              :scope => 'instance', :language => 'ruby', :data => 'puts 1')
  end

  it 'fetch a instance by name' do
    MiqAeInstance.find_by_name('INST1').should_not be_nil
  end

  it 'fetch a method by name' do
    MiqAeMethod.find_by_name('METH1').should_not be_nil
  end

  it 'fetch a class by name' do
    MiqAeClass.find_by_name('KLASS1').should_not be_nil
  end

  it 'fetch a namespace by name' do
    MiqAeNamespace.find_by_name('NS1').should_not be_nil
  end

  it 'fetch a domain by name' do
    MiqAeDomain.find_by_name('ABC').should_not be_nil
  end
end
