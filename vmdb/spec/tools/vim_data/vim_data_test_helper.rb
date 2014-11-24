require 'yaml'

# Create a dummy Handsoap::Fault class since callers may be expecting it.
module Handsoap
  class Fault < RuntimeError
    attr_reader :code, :reason, :details
    def initialize(code, reason, details)
      @code = code
      @reason = reason
      @details = details
    end
    def to_s
      "Handsoap::Fault { :code => '#{@code}', :reason => '#{@reason}' }"
    end
  end
end

class FakeMiqVimHandleBase
  VIM_DATA_DIR = File.dirname(__FILE__)

  def self.clear_data
    @data = nil
  end

  def self.load_data(m, dir)
    @data ||= {}
    @data[dir] ||= {}
    @data[dir][m.to_sym] ||= begin
      file = File.expand_path(File.join(VIM_DATA_DIR, dir, "#{m}.yml"))
      File.exist?(file) ? YAML.load_file(file) : nil
    end
  end

  def _load_data(m)
    FakeMiqVimHandleBase.load_data(m, self.class::DATA_DIR)
  end

  def _dup_data(data)
    data.nil? ? nil : data.deep_clone
  end

  def disconnect
    # Do nothing
  end
  alias release disconnect

  def method_missing(m, *args)
    _dup_data(_load_data(m))
  end
end

class FakeMiqVimHandle < FakeMiqVimHandleBase
  DATA_DIR = "miq_vim_inventory"

  def about
    {
      "apiVersion"   => "4.1",
      "instanceUuid" => "EF53782F-6F1A-4471-B338-72B27774AFDD"
    }
  end

  def method_missing(m, *args)
    m = m.to_s
    byMor = (m[-5..-1] == "ByMor" && m[-6, 1] != "s")
    data = _load_data(byMor ? m.insert(-6, 's') : m)
    _dup_data(byMor ? data[args.first] : data)
  end

  def getVimCustomizationSpecManager
    FakeMiqVimCustomizationSpecManager.new
  end

  def getVimHostByMor(mor)
    FakeMiqVimHost.new(mor)
  end

  def getVimPerfHistory
    FakeMiqVimPerfHistory.new
  end
end

class FakeMiqVimCustomizationSpecManager < FakeMiqVimHandleBase
  DATA_DIR = "miq_vim_inventory"
end

class FakeMiqVimHost < FakeMiqVimHandleBase
  DATA_DIR = "miq_vim_inventory"

  def initialize(mor)
    @mor = mor
  end

  def storageDevice(*args)
    _dup_data(_load_data(:storageDevice)[@mor])
  end
end

class FakeMiqVimPerfHistory < FakeMiqVimHandleBase
  DATA_DIR = "miq_vim_perf_history"

  def queryProviderSummary(mor)
    _dup_data(_load_data(:queryProviderSummary)[mor])
  end

  def availMetricsForEntity(mor, options = {})
    _dup_data(_load_data(:availMetricsForEntity).fetch_path(mor, options[:intervalId]))
  end

  def queryPerfMulti(query)
    raise "unexpected query" if query.length != 1
    _dup_data(_load_data(:queryPerfMulti).fetch_path(query[0].values_at(:entity, :intervalId, :startTime, :endTime)))
  end
end
