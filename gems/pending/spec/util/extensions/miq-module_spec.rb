require 'util/extensions/miq-module'
require 'timecop'

describe Module do
  let(:test_class)  { Class.new }
  let(:test_module) { Module.new }

  context '#cache_with_timeout' do
    before(:each) do
      @settings = 60

      expect { test_class.cache_with_timeout(:default) { rand } }.not_to raise_error
      expect { test_class.cache_with_timeout(:override, 60) { rand } }.not_to raise_error
      expect { test_class.cache_with_timeout(:override_proc, -> { @settings }) { rand } }.not_to raise_error

      expect { test_module.cache_with_timeout(:default) { rand } }.not_to raise_error
    end

    after(:each) do
      Module.clear_all_cache_with_timeout
    end

    it 'will create the class method on that class/module only' do
      expect(test_class).to  respond_to(:default)
      expect(test_class.new).not_to respond_to(:default)
      expect(Object).not_to respond_to(:default)
      expect(Class).not_to  respond_to(:default)
      expect(Module).not_to respond_to(:default)

      expect(test_module).to respond_to(:default)
      expect(Object).not_to respond_to(:default)
      expect(Class).not_to  respond_to(:default)
      expect(Module).not_to respond_to(:default)
    end

    it 'will return the cached value' do
      value = test_class.default(true)
      expect(test_class.default).to eq(value)

      value = test_module.default(true)
      expect(test_module.default).to eq(value)
    end

    it 'will not return the cached value when passed force_reload = true' do
      value = test_class.default(true)
      expect(test_class.default(true)).not_to eq(value)

      value = test_module.default(true)
      expect(test_module.default(true)).not_to eq(value)
    end

    it 'will return the cached value if the default timeout has not passed' do
      value = test_class.default(true)
      Timecop.travel(60) { expect(test_class.default).to eq(value) }
    end

    it 'will not return the cached value if the default timeout has passed' do
      value = test_class.default(true)
      Timecop.travel(600) { expect(test_class.default).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout has not passed' do
      value = test_class.override(true)
      Timecop.travel(30) { expect(test_class.override).to eq(value) }
    end

    it 'will not return the cached value if the overridden timeout has passed' do
      value = test_class.override(true)
      Timecop.travel(120) { expect(test_class.override).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout (via a proc) has not passed' do
      value = test_class.override_proc(true)
      Timecop.travel(30) { expect(test_class.override_proc).to eq(value) }
    end

    it 'will not return the cached value if the overridden timeout (via a proc) has passed' do
      value = test_class.override_proc(true)
      Timecop.travel(120) { expect(test_class.override_proc).not_to eq(value) }
    end

    it 'will return the cached value if the overridden timeout (via a proc) was changed but has not passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = test_class.override_proc(true)
      Timecop.travel(120) { expect(test_class.override_proc).to eq(value) }
      @settings = 60 # reset back to 1 minute
    end

    it 'will not return the cached value if the overridden timeout (via a proc) was changed and has passed' do
      # Test a time jump value between the old settings value and the new to
      # prove that the new value is working
      @settings = 300 # 5 minutes
      value = test_class.override_proc(true)
      Timecop.travel(600) { expect(test_class.override_proc).not_to eq(value) }
      @settings = 60 # reset back to 1 minute
    end

    it 'generated .*_clear_cache' do
      test_class.default
      test_class.override
      test_class.override_proc
      test_module.default

      test_class.default_clear_cache
      test_class.override_clear_cache
      test_class.override_proc_clear_cache
      test_module.default_clear_cache

      expect(test_class.default_cached?).to be_falsey
      expect(test_class.override_cached?).to be_falsey
      expect(test_class.override_proc_cached?).to be_falsey
      expect(test_module.default_cached?).to be_falsey
    end

    it 'generated .*_cached?' do
      expect(test_class.default_cached?).to be_falsey
      expect(test_class.override_cached?).to be_falsey
      expect(test_class.override_proc_cached?).to be_falsey
      expect(test_module.default_cached?).to be_falsey

      test_class.default
      test_class.override
      test_class.override_proc
      test_module.default

      expect(test_class.default_cached?).to be_truthy
      expect(test_class.override_cached?).to be_truthy
      expect(test_class.override_proc_cached?).to be_truthy
      expect(test_module.default_cached?).to be_truthy
    end

    it 'will cache with thread safety' do
      # If multiple threads access the in-memory cache without thread safety,
      #   and one tries to force reload, there is a small window where as it
      #   clears the current value, the other thread could get nil.
      test_class.cache_with_timeout(:thread_safety) { 2 }

      Thread.new do
        10000.times do
          test_class.thread_safety(true)
        end
      end

      10000.times do
        expect(test_class.thread_safety).to eq(2)
      end
    end
  end
end
