require 'manageiq-password'

module FixAuth
  module AuthModel
    extend ActiveSupport::Concern

    module ClassMethods
      attr_accessor :password_columns

      def available_columns
        column_names & password_columns
      end

      def select_columns
        [:id] + available_columns
      end

      def contenders
        where(selection_criteria).select(select_columns)
      end

      # bring back anything with a password column that has a non blank v1 or v2 password in it
      def selection_criteria
        available_columns.collect do |column|
          "(#{column} like '%v2:{%')"
        end.join(" OR ")
      end

      def hardcode(_old_value, new_value)
        ManageIQ::Password.encrypt(new_value)
      end

      def recrypt(old_value, options = {})
        if options[:hardcode]
          hardcode(old_value, options[:hardcode])
        else
          ManageIQ::Password.new.recrypt(old_value)
        end
      rescue
        if options[:invalid]
          hardcode(old_value, options[:invalid])
        else
          raise
        end
      end

      def fix_passwords(obj, options = {})
        available_columns.each do |column|
          if (old_value = obj.send(column)).present?
            new_value = recrypt(old_value, options)
            obj.send("#{column}=", new_value) if new_value != old_value
          end
        end
        obj
      end

      def highlight_password(value, options)
        return if value.blank?
        if options[:hardcode] && (value == ManageIQ::Password.encrypt(options[:hardcode]))
          "#{value} HARDCODED"
        elsif options[:invalid] && (value == ManageIQ::Password.encrypt(options[:invalid]))
          "#{value} HARDCODED (WAS INVALID)"
        else
          value
        end
      end

      def in_destination_format?(value)
        value.blank? || value =~ /^v2:\{.*\}$/
      end

      def display_record(r)
        puts "  #{r.id}:"
      end

      def display_column(r, column, options)
        v = r.send(column)
        if r.send("#{column}_changed?")
          puts "    #{column}: #{r.send("#{column}_was").inspect} => #{highlight_password(v, options)}"
        elsif r.send(column).present?
          puts "    #{column}: #{v.inspect} (not changed)"
        end
      end

      def run(options = {})
        return if available_columns.empty?
        puts "fixing #{table_name}.#{available_columns.join(", ")}" unless options[:silent]
        processed = 0
        errors = 0
        would_make_changes = false
        contenders.each do |r|
          begin
            fix_passwords(r, options)
            if options[:verbose]
              display_record(r)
              available_columns.each do |column|
                display_column(r, column, options)
              end
            end
            would_make_changes ||= r.changed?
            r.save! if !options[:dry_run] && r.changed?
            processed += 1
          rescue ArgumentError # undefined class/module
            errors += 1
            unless options[:allow_failures]
              STDERR.puts "unable to fix #{r.class.table_name}:#{r.id}" unless options[:silent]
              raise
            end
          end
          if !options[:silent] && (errors + processed) % 10_000 == 0
            puts "processed #{processed} with #{errors} errors"
          end
        end
        puts "#{options[:dry_run] ? "viewed" : "processed"} #{processed} records" unless options[:silent]
        puts "found #{errors} errors" if errors > 0 && !options[:silent]
        puts "** This was executed in dry-run, and no actual changes will be made to #{table_name} **" if would_make_changes && options[:dry_run]
      end

      def clean_up
        clear_active_connections!
      end
    end
  end
end
