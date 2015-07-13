require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-class'

describe Class do
  it "#hierarchy" do
    object_hierachy = [Object, BasicObject]
    Object.hierarchy.should        == object_hierachy
    Exception.hierarchy.should     == [Exception] + object_hierachy
    StandardError.hierarchy.should == [StandardError, Exception] + object_hierachy
  end

  it "#subclass_of?" do
    Object.should_not        be_subclass_of Object

    Exception.should         be_subclass_of Object
    Exception.should_not     be_subclass_of Exception

    StandardError.should     be_subclass_of Object
    StandardError.should     be_subclass_of Exception
    StandardError.should_not be_subclass_of StandardError

    Array.should_not         be_subclass_of StandardError
  end

  it "#is_or_subclass_of?" do
    Object.should            be_is_or_subclass_of Object

    Exception.should         be_is_or_subclass_of Object
    Exception.should         be_is_or_subclass_of Exception

    StandardError.should     be_is_or_subclass_of Object
    StandardError.should     be_is_or_subclass_of Exception
    StandardError.should     be_is_or_subclass_of StandardError

    Array.should_not         be_is_or_subclass_of StandardError
  end

  it "#superclass_of?" do
    Object.should_not        be_superclass_of Object

    Object.should            be_superclass_of Exception
    Exception.should_not     be_superclass_of Exception

    Object.should            be_superclass_of StandardError
    Exception.should         be_superclass_of StandardError
    StandardError.should_not be_superclass_of StandardError

    Array.should_not         be_superclass_of StandardError
  end

  it "#is_or_superclass_of?" do
    Object.should            be_is_or_superclass_of Object

    Object.should            be_is_or_superclass_of Exception
    Exception.should         be_is_or_superclass_of Exception

    Object.should            be_is_or_superclass_of StandardError
    Exception.should         be_is_or_superclass_of StandardError
    StandardError.should     be_is_or_superclass_of StandardError

    Array.should_not         be_is_or_superclass_of StandardError
  end
end
