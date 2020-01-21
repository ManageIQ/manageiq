class OpenscapResult < ApplicationRecord
  belongs_to :container_image
  belongs_to :resource,              :polymorphic => true
  has_one    :binary_blob,           :dependent => :destroy, :autosave => true, :as => :resource, :required => true
  has_many   :openscap_rule_results, :dependent => :destroy, :autosave => true

  before_save :create_rule_results

  def self.openscap_available?
    # needed only for travis
    require 'openscap'
    require 'openscap/ds/arf'
    require 'openscap/xccdf/benchmark'
    true
  rescue LoadError
    false
  end

  def attach_raw_result(openscap_arf)
    self.binary_blob = BinaryBlob.new(:name => 'openscap_compliance_arf', :data_type => 'XML')
    binary_blob.binary = openscap_arf
  end

  def html
    with_openscap_arf(binary_blob.binary) do |arf|
      ascii8bit_to_utf8(arf.html)
    end
  end

  private

  def create_rule_results
    with_openscap_objects(binary_blob.binary) do |rule_results, benchmark_items|
      create_results(rule_results, benchmark_items)
    end
  end

  def create_results(rule_results, benchmark_items)
    openscap_rule_results.delete_all
    rule_results.each do |openscap_id, result|
      idents = []
      benchmark_items[openscap_id].idents.each do |ident|
        idents << ident.id
      end
      openscap_rule_results << OpenscapRuleResult.new(
        :name            => ascii8bit_to_utf8(openscap_id),
        :result          => ascii8bit_to_utf8(result.result),
        :openscap_result => self,
        :severity        => ascii8bit_to_utf8(benchmark_items[openscap_id].severity),
        :title           => ascii8bit_to_utf8(benchmark_items[openscap_id].title),
        :cves            => idents.join(",")
      )
    end
  end

  def ascii8bit_to_utf8(string)
    string.to_s.encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')
  end

  def with_openscap_arf(raw)
    return unless self.class.openscap_available?
    begin
      OpenSCAP.oscap_init
      # ARF - nist standardized 'Asset Reporting Format' Full representation if a scap scan result.
      arf = OpenSCAP::DS::Arf.new(:content => raw, :length => raw.length, :path => 'incoming_arf.xml')
      yield arf
    ensure
      OpenSCAP.oscap_cleanup
      arf.try(:destroy)
    end
  end

  def with_openscap_objects(raw)
    raise "no block given" unless block_given?
    with_openscap_arf(raw) do |arf|
      begin
        test_results = arf.test_result
        source_datastream = arf.report_request
        bench_source = source_datastream.select_checklist!
        benchmark = OpenSCAP::Xccdf::Benchmark.new(bench_source)
        yield(test_results.rr, benchmark.items)
      ensure
        [benchmark, source_datastream, test_results].each { |obj| obj.try(:destroy) }
      end
    end
  end
end
