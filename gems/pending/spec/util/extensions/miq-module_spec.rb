require 'util/extensions/miq-module'
require 'timecop'

describe Module do
  class ::TestClass; end
  module ::TestModule; end

  context '#cache_with_timeout' do
    before(:each) do
      @settings = 60

      expect { TestClass.cache_with_timeout(:default) { rand } }.not_to raise_error
      expect { TestClass.cache_with_timeout(:override, 60) { rand } }.not_to raise_error
      expect { TestClass.cache_with_timeout(:override_proc, -> { @settings }) { rand } }.not_to raise_error

      expect { TestModule.cache_with_timeout(:default) { rand } }.not_to raise_error
    end

    after(:each) do
      Module.clear_all_cache_with_timeout
    end

    it 'will create the class method on that class/module only' do
      expect(TestClass).to  respond_to(:default)
      expect(TestClass.new).not_to respond_to(:default)
      expect(Object).not_to respond_to(:default)
      expect(Class).not_to  respond_to(:default)
      expect(Module).not_to respond_to(:default)

      expect(TestModule).to respond_to(:default)
      expect(Object).not_to respond_to(:default)
      expect(Class).not_to  respond_to(:default)
      expect(Module).not_to respond_to(:default)
    end

    it 'will return the cached value' do
      value = TestClass.default(true)
      expect(TestClass.default).to eq(value)

      value = TestModule.default(true)
      expect(TestModule.default).to eq(value)
    end

    it 'will not return the cached value when passed force_reload = true' do
      value = TestClass.default(true)
      expect(TestClass.default(true)).not_to eq(value)

      value = TestModule.default(true)
      expect(TestModule.default(true)).not_to eq(value)
    end

    it 'will return the cached value if the default timeout has not passed' do
      value = TestClass.default(true)
      Timecop.travel(60) { expect(TestClass.default).to eq(value) }
    end

    it 'will not return the cached value if the default timeout has passed' do
      value = TestClass.default(true)
      Timecop.travel(600) { expect(TestClass.default).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout has not passed' do
      value = TestClass.override(true)
      Timecop.travel(30) { expect(TestClass.override).to eq(value) }
    end

    it 'will not return the cached value if the overridden timeout has passed' do
      value = TestClass.override(true)
      Timecop.travel(120) { expect(TestClass.override).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout (via a proc) has not passed' do
      value = TestClass.override_proc(true)
      Timecop.travel(30) { expect(TestClass.override_proc).to eq(value) }
    end

    it 'will not return the cached value if the overridden timeout (via a proc) has passed' do
      value = TestClass.override_proc(true)
      Timecop.travel(120) { expect(TestClass.override_proc).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout (via a proc) was changed but has not passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = TestClass.override_proc(true)
      Timecop.travel(120) { expect(TestClass.override_proc).to eq(value) }
      @settings = 60 # reset back to 1 minute
    end

    it 'will not return the cached value if the overridden timeout (via a proc) was changed and has passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = TestClass.override_proc(true)
      Timecop.travel(600) { expect(TestClass.override_proc).not_to eq(value) }
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

      expect(TestClass.default_cached?).to be_falsey
      expect(TestClass.override_cached?).to be_falsey
      expect(TestClass.override_proc_cached?).to be_falsey
      expect(TestModule.default_cached?).to be_falsey
    end

    it 'generated .*_cached?' do
      expect(TestClass.default_cached?).to be_falsey
      expect(TestClass.override_cached?).to be_falsey
      expect(TestClass.override_proc_cached?).to be_falsey
      expect(TestModule.default_cached?).to be_falsey

      TestClass.default
      TestClass.override
      TestClass.override_proc
      TestModule.default

      expect(TestClass.default_cached?).to be_truthy
      expect(TestClass.override_cached?).to be_truthy
      expect(TestClass.override_proc_cached?).to be_truthy
      expect(TestModule.default_cached?).to be_truthy
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
        expect(TestClass.thread_safety).to eq(2)
      end
    end
  end
end
