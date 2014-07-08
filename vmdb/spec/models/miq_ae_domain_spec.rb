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
end
