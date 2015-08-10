require 'spec_helper'

describe MiqAeDatastore do
  before do
    @dom = MiqAeDomain.create(:name => 'ABC', :enabled => true)
    @ns  = MiqAeNamespace.create(:name => 'NS1', :parent_id => @dom.id)
    @cls = MiqAeClass.create(:name => 'KLASS1', :namespace_id => @ns.id, :description => 'A Class')
    @ins = MiqAeInstance.create(:name => 'INST1', :class_id => @cls.id)
    @met = MiqAeMethod.create(:name => 'METH1', :class_id => @cls.id, :location => 'inline',
                              :scope => 'instance', :language => 'ruby', :data => 'puts 1')
  end
  it 'rename a domain' do
    @dom.update_attributes(:name => 'XYZ')
    MiqAeDomain.find_by_fqname('ABC').should be_nil
    MiqAeDomain.find_by_fqname('XYZ').should_not be_nil
    MiqAeInstance.find_by_fqname('XYZ/NS1/KLASS1/INST1').should_not be_nil
  end

  it 'rename a namespace' do
    @ns.update_attributes(:name => 'XYZ')
    MiqAeNamespace.find_by_fqname('ABC/NS1').should be_nil
    MiqAeNamespace.find_by_fqname('ABC/XYZ').should_not be_nil
    MiqAeInstance.find_by_fqname('ABC/XYZ/KLASS1/INST1').should_not be_nil
  end

  it 'rename a class' do
    @cls.update_attributes(:name => 'XYZ')
    MiqAeClass.find_by_fqname('ABC/NS1/KLASS1').should be_nil
    MiqAeClass.find_by_fqname('ABC/NS1/XYZ').should_not be_nil
    MiqAeInstance.find_by_fqname('ABC/NS1/XYZ/INST1').should_not be_nil
  end

  it 'rename an instance' do
    @ins.update_attributes(:name => 'XYZ')
    MiqAeInstance.find_by_fqname('ABC/NS1/KLASS1/INST1').should be_nil
    MiqAeInstance.find_by_fqname('ABC/NS1/KLASS1/XYZ').should_not be_nil
  end

  it 'rename a method' do
    @met.update_attributes(:name => 'XYZ')
    MiqAeMethod.find_by_fqname('ABC/NS1/KLASS1/METH1').should be_nil
    MiqAeMethod.find_by_fqname('ABC/NS1/KLASS1/XYZ').should_not be_nil
  end
end
