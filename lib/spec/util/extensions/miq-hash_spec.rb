require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-hash'

# Subclass of String to test []= substring complex key patch
class SubString < String
  attr_accessor :sub_str
end

describe Hash do
  it '#[]= with a substring key' do
    s = SubString.new("string")
    s.sub_str = "substring"

    h = {}
    h[s] = "test"
    s2 = h.keys.first

    s2.should == s
    s2.sub_str.should == s.sub_str
  end

  it "#sort!" do
    h = {:x => 1, :b => 2, :y => 3, :a => 4}
    h_id = h.object_id

    h.sort!

    h.keys.should      == [:a, :b, :x, :y]
    h.object_id.should == h_id
  end

  it "#sort_by!" do
    h = {:x => 1, :b => 2, :y => 3, :a => 4}
    h_id = h.object_id

    h.sort_by! { |k, _v| k }

    h.keys.should      == [:a, :b, :x, :y]
    h.object_id.should == h_id
  end
end
