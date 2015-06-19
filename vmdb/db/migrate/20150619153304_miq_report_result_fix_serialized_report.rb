class MiqReportResultFixSerializedReport < ActiveRecord::Migration
  class MiqReportResult < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    def serialize_report_to_hash
      val = read_attribute(:report)

      if val.include?("!ruby/object:MiqReport")
        val.sub!(/MiqReport/, 'Hash')
      else
        raise "unexpected format of report attribute encountered,  '#{val.inspect}'"
      end

      YAML.dump(YAML.load(val).last['attributes'])
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
    end
  end
end
