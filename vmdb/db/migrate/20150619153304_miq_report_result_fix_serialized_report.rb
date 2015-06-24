class MiqReportResultFixSerializedReport < ActiveRecord::Migration
  class MiqReportResult < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    YAML_ATTRS = [:table, :sub_table, :filter_summary, :extras, :ids, :scoped_association, :html_title, :file_name, :extras, :record_id,
                  :tl_times, :user_categories, :trend_data, :performance, :include_for_find, :report_run_time, :chart, :reserved]

    def serialize_report_to_hash
      val = read_attribute(:report)

      if val.include?("!ruby/object:MiqReport")
        val.sub!(/MiqReport/, 'Hash')
      else
        raise "unexpected format of report attribute encountered,  '#{val.inspect}'"
      end
      raw_hash = YAML.load(val).last
      new_hash = YAML_ATTRS.each_with_object(raw_hash['attributes'].to_hash) { |k, h| h[k.to_s] = raw_hash[k.to_s] }

      YAML.dump(new_hash)
    end

    def serialize_hash_to_report
      val = read_attribute(:report)

      if val.starts_with?("---")
        YAML.dump([MiqReport.new(YAML.load(val))])
      else
        raise "unexpected format of report attribute encountered,  '#{val.inspect}'"
      end
    end
  end

  def up
    say_with_time("Converting MiqReportResult#report to a serialized hash") do
      MiqReportResult.where('report IS NOT NULL').each do |rr|
        rr.update_attribute(:report, rr.serialize_report_to_hash)
      end
    end
  end

  def down
    say_with_time("Converting MiqReportResult#report back to a serialized MiqReport") do
      MiqReportResult.where('report IS NOT NULL').each do |rr|
        rr.update_attribute(:report, rr.serialize_hash_to_report)
      end
    end
  end
end
