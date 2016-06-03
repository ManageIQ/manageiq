require "parallel"

class FixSerializedReportsForRailsFour < ActiveRecord::Migration
  disable_ddl_transaction!
  include MigrationHelper

  module Serializer
    YAML_ATTRS = [:table, :sub_table, :filter_summary, :extras, :ids, :scoped_association, :html_title, :file_name,
                  :extras, :record_id, :tl_times, :user_categories, :trend_data, :performance, :include_for_find,
                  :report_run_time, :chart, :reserved].to_set

    def self.serialize_report_to_hash(val, klass, id, migration)
      if val.include?("!ruby/object:MiqReport")
        val.sub!(/MiqReport/, 'Hash')
      elsif val.starts_with?('--- !')
        migration.say "#{klass} id: #{id} does not contain an MiqReport object, skipping conversion", :subitem
        return
      elsif val.starts_with?("---\n")
        return # Record has already been converted
      else
        raise "unexpected format of report attribute encountered, '#{val.inspect.truncate(10000)}'"
      end
      raw_hash = YAML.load(val)
      # MiqReport was serialized as an Array with 1 element in miq_report_results
      raw_hash = raw_hash.last if raw_hash.kind_of?(Array)
      #
      new_hash = YAML_ATTRS.each_with_object(raw_hash['attributes'].to_hash) { |k, h| h[k.to_s] = raw_hash[k.to_s] }

      YAML.dump(new_hash)
    end

    def self.serialize_hash_to_report(val, from, klass, id, migration)
      if val.starts_with?('--- !')
        migration.say "#{klass} id: #{id} does not contain a Hash, skipping conversion", :subitem
      elsif val.starts_with?("---")
        new_hash = {'attributes' => {}}
        YAML.load(val).each do |k, v|
          YAML_ATTRS.include?(k.to_sym) ? new_hash[k.to_s] = v : new_hash['attributes'][k.to_s] = v
        end

        if from == :miq_report_result
          # MiqReport was serialized as an Array with 1 element in miq_report_results
          YAML.dump([new_hash]).sub(/---\n- attributes:/, "---\n- !ruby/object:MiqReport\n  attributes:")
        else
          YAML.dump(new_hash).sub(/---/, "--- !ruby/object:MiqReport")
        end
      elsif val.include?("!ruby/object:MiqReport")
        return # Record has already been converted
      else
        raise "unexpected format of report attribute encountered, '#{val.inspect.truncate(10000)}'"
      end
    end
  end

  class MiqReportResult < ActiveRecord::Base
  end

  class BinaryBlobPart < ActiveRecord::Base
    def self.default_part_size
      @default_part_size ||= 1.megabyte
    end

    def data
      val = read_attribute(:data)
      raise "size of #{self.class.name} id [#{id}] is incorrect" unless size.nil? || size == val.bytesize
      raise "md5 of #{self.class.name} id [#{id}] is incorrect" unless md5.nil? || md5 == Digest::MD5.hexdigest(val)
      val
    end

    def data=(val)
      raise ArgumentError, "data cannot be set to nil" if val.nil?
      write_attribute(:data, val)
      self.md5 = Digest::MD5.hexdigest(val)
      self.size = val.bytesize
      self
    end
  end

  class BinaryBlob < ActiveRecord::Base
    has_many :binary_blob_parts, -> { order(:id) }, :class_name => 'FixSerializedReportsForRailsFour::BinaryBlobPart'
    belongs_to :resource, :class_name => 'FixSerializedReportsForRailsFour::MiqReportResult'

    def delete_binary
      self.md5 = self.size = self.part_size = nil
      binary_blob_parts.delete_all
      self.save!
    end

    def binary
      data = binary_blob_parts.inject("") do |d, b|
        d << b.data
        d
      end
      raise "size of #{self.class.name} id [#{id}] is incorrect" unless size.nil? || size == data.bytesize
      raise "md5 of #{self.class.name} id [#{id}] is incorrect" unless md5.nil? || md5 == Digest::MD5.hexdigest(data)
      data
    end

    def binary=(data)
      data.force_encoding('ASCII-8BIT')
      delete_binary unless parts == 0
      return self if data.bytesize == 0

      self.part_size ||= BinaryBlobPart.default_part_size
      self.md5 = Digest::MD5.hexdigest(data)
      self.size = data.bytesize

      until data.bytesize == 0
        buf = data.slice!(0..self.part_size)
        binary_blob_parts << BinaryBlobPart.new(:data => buf)
      end
      self.save!

      self
    end

    def parts
      binary_blob_parts.size
    end
  end

  def up
    say_with_time("Converting MiqReportResult#report to a serialized hash") do
      base_relation = MiqReportResult.where('report IS NOT NULL')

      say_batch_started(base_relation.size)

      base_relation.find_in_batches do |batch|
        MiqReportResult.transaction do
          batch.each do |rr|
            val = Serializer.serialize_report_to_hash(rr.report, rr.class, rr.id, self)
            rr.update_attribute(:report, val) if val
          end
        end
        say_batch_processed(batch.size)
      end
    end

    say_with_time("Converting BinaryBlob report results to a serialized hash") do
      # Pre-autoload classes that appear in reports
      MiqExpression
      Ruport

      all_ids = BinaryBlob
                  .where(:resource_type => 'MiqReportResult')
                  .select(:id, :resource_id, :resource_type)
                  .includes(:resource)
                  .select(&:resource) # Ignore orphaned BinaryBlob records
                  .map(&:id)

      say_batch_started(all_ids.size)

      all_ids.each_slice(1000) do |ids|
        bbs = BinaryBlob.where(:id => ids)

        # Extract the binaries from the AR objects so we don't have to pass
        #   the AR objects through to Parallel
        MiqPreloader.preload(bbs, :binary_blob_parts)
        payload = bbs.map { |bb| [bb.binary, bb.class.name, bb.id] }

        # Convert the binaries in parallel processes
        converted = Parallel.map(payload) do |binary, klass, id|
          close_pg_sockets_inherited_from_parent
          Serializer.serialize_report_to_hash(binary, klass, id, self)
        end
        reset_db_connections_after_parallel_forking

        # Write the new binaries in a single transaction
        BinaryBlob.transaction do
          bbs.zip(converted).each do |bb, val|
            bb.binary = val if val
          end
        end

        say_batch_processed(ids.size)
      end
    end
  end

  def down
    say_with_time("Converting MiqReportResult#report back to a serialized MiqReport") do
      MiqReportResult.where('report IS NOT NULL').find_each do |rr|
        val = Serializer.serialize_hash_to_report(rr.report, :miq_report_result, rr.class, rr.id, self)
        rr.update_attribute(:report, val) if val
      end
    end

    say_with_time("Converting BinaryBlob report results back to a serialized MiqReport") do
      BinaryBlob.includes(:resource).where(:resource_type => 'MiqReportResult').find_each do |bb|
        if bb.resource
          val = Serializer.serialize_hash_to_report(bb.binary, :binary_blob, bb.class, bb.id, self)
          bb.binary = val if val
        end
      end
    end
  end
end
