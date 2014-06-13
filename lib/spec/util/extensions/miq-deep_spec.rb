require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-deep'

describe 'miq-deep' do
  CASE_HASH  = {"BETWEEN"=>{:name=>"test", :value=>[1,2], :token=>1}}
  CASE_ARRAY = [{"BETWEEN"=>{:name=>"test", :value=>[1,2], :token=>1}}]

  it 'Hash#deep_clone' do
    should_deep_clone(CASE_HASH.deep_clone, CASE_HASH)
  end

  it 'Array#deep_clone' do
    should_deep_clone(CASE_ARRAY.deep_clone, CASE_ARRAY)
  end

  it 'Hash#deep_delete' do
    normal_delete = CASE_HASH.deep_clone
    normal_delete["BETWEEN"].delete(:token)

    h = CASE_HASH.deep_clone
    h = h.deep_delete(:token)
    h.should == normal_delete
  end

  it 'Array#deep_delete' do
    normal_delete = CASE_ARRAY.deep_clone
    normal_delete[0]["BETWEEN"].delete(:token)

    h = CASE_ARRAY.deep_clone
    h = h.deep_delete(:token)
    h.should == normal_delete
  end

  # TODO: More test cases for deleting other keys, and deleting multiple keys

  def should_deep_clone(o1, o2)
    o1.should == o2
    o1.should_not equal(o2)

    # TODO: Add test cases that show that all sub-elements are cloned properly
  end
end
