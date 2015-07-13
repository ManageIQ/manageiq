require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-module'

require 'timecop'

describe Module do
  class ::TestClass; end
  module ::TestModule; end

  context '#cache_with_timeout' do
    before(:each) do
      @settings = 60

      lambda { TestClass.cache_with_timeout(:default) {rand} }.should_not raise_error
      lambda { TestClass.cache_with_timeout(:override, 60) {rand} }.should_not raise_error
      lambda { TestClass.cache_with_timeout(:override_proc, lambda { @settings }) {rand} }.should_not raise_error

      lambda { TestModule.cache_with_timeout(:default) {rand} }.should_not raise_error
    end

    after(:each) do
      $miq_cache_with_timeout.clear
    end

    it 'will create the class method on that class/module only' do
      TestClass.should  respond_to(:default)
      TestClass.new.should_not respond_to(:default)
      Object.should_not respond_to(:default)
      Class.should_not  respond_to(:default)
      Module.should_not respond_to(:default)

      TestModule.should respond_to(:default)
      Object.should_not respond_to(:default)
      Class.should_not  respond_to(:default)
      Module.should_not respond_to(:default)
    end

    it 'will return the cached value' do
      value = TestClass.default(true)
      TestClass.default.should == value

      value = TestModule.default(true)
      TestModule.default.should == value
    end

    it 'will not return the cached value when passed force_reload = true' do
      value = TestClass.default(true)
      TestClass.default(true).should_not == value

      value = TestModule.default(true)
      TestModule.default(true).should_not == value
    end

    it 'will return the cached value if the default timeout has not passed' do
      value = TestClass.default(true)
      Timecop.travel(60) { TestClass.default.should == value }
    end

    it 'will not return the cached value if the default timeout has passed' do
      value = TestClass.default(true)
      Timecop.travel(600) { TestClass.default.should_not == value }
    end

    it 'will return the cached value if the overridden timeout has not passed' do
      value = TestClass.override(true)
      Timecop.travel(30) { TestClass.override.should == value }
    end

    it 'will not return the cached value if the overridden timeout has passed' do
      value = TestClass.override(true)
      Timecop.travel(120) { TestClass.override.should_not == value }
    end

    it 'will return the cached value if the overridden timeout (via a proc) has not passed' do
      value = TestClass.override_proc(true)
      Timecop.travel(30) { TestClass.override_proc.should == value }
    end

    it 'will not return the cached value if the overridden timeout (via a proc) has passed' do
      value = TestClass.override_proc(true)
      Timecop.travel(120) { TestClass.override_proc.should_not == value }
    end

    it 'will return the cached value if the overridden timeout (via a proc) was changed but has not passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = TestClass.override_proc(true)
      Timecop.travel(120) { TestClass.override_proc.should == value }
      @settings = 60 # reset back to 1 minute
    end

    it 'will not return the cached value if the overridden timeout (via a proc) was changed and has passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = TestClass.override_proc(true)
      Timecop.travel(600) { TestClass.override_proc.should_not == value }
      @settings = 60 # reset back to 1 minute
    end

    it 'generated .*_clear_cache' do
      TestClass.default
      TestClass.override
      TestClass.override_proc
      TestModule.default

      TestClass.default_clear_cache
      TestClass.override_clear_cache
      TestClass.override_proc_clear_cache
      TestModule.default_clear_cache

      TestClass.default_cached?.should be_false
      TestClass.override_cached?.should be_false
      TestClass.override_proc_cached?.should be_false
      TestModule.default_cached?.should be_false
    end

    it 'generated .*_cached?' do
      TestClass.default_cached?.should be_false
      TestClass.override_cached?.should be_false
      TestClass.override_proc_cached?.should be_false
      TestModule.default_cached?.should be_false

      TestClass.default
      TestClass.override
      TestClass.override_proc
      TestModule.default

      TestClass.default_cached?.should be_true
      TestClass.override_cached?.should be_true
      TestClass.override_proc_cached?.should be_true
      TestModule.default_cached?.should be_true
    end

    it 'will cache with thread safety' do
      # If multiple threads access the in-memory cache without thread safety,
      #   and one tries to force reload, there is a small window where as it
      #   clears the current value, the other thread could get nil.
      TestClass.cache_with_timeout(:thread_safety) { 2 }

      Thread.new do
        10000.times do
          TestClass.thread_safety(true)
        end
      end

      10000.times do
        TestClass.thread_safety.should == 2
      end
    end
  end
end
