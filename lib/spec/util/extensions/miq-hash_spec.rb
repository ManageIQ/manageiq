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
end
