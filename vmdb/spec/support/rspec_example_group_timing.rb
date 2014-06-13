if RSpec::Core::Formatters::BaseTextFormatter.instance_methods.include?(:dump_profile_slowest_example_groups)
  warn("*****************************************************************")
  warn("You are using a version of rspec-core that includes this feature.")
  warn("Time to delete #{__FILE__}")
  warn("*****************************************************************")
else

module RSpec
  module Core
    module Formatters
      class BaseTextFormatter < BaseFormatter
        alias dump_profile_examples dump_profile

        def dump_profile
          dump_profile_slowest_examples
          dump_profile_slowest_example_groups
        end

        def dump_profile_slowest_examples
          number_of_examples = 10
          sorted_examples = examples.sort_by {|example|
            example.execution_result[:run_time] }.reverse.first(number_of_examples)

          total, slows = [examples, sorted_examples].map {|exs|
            exs.inject(0.0) {|i, e| i + e.execution_result[:run_time] }}

          time_taken = slows / total
          percentage = '%.1f' % ((time_taken.nan? ? 0.0 : time_taken) * 100)

          output.puts "\nTop #{sorted_examples.size} slowest examples (#{format_seconds(slows)} seconds, #{percentage}% of total time):\n"

          sorted_examples.each do |example|
            output.puts "  #{example.full_description}"
            output.puts cyan("    #{red(format_seconds(example.execution_result[:run_time]))} #{red("seconds")} #{format_caller(example.location)}")
          end
        end

        def dump_profile_slowest_example_groups
          number_of_examples = 10
          example_groups = {}

          examples.each do |example|
            location = example.example_group.parent_groups.last.metadata[:example_group][:location]

            example_groups[location] ||= Hash.new(0)
            example_groups[location][:total_time]  += example.execution_result[:run_time]
            example_groups[location][:count]       += 1
            example_groups[location][:description] = example.example_group.top_level_description unless example_groups[location].has_key?(:description)
          end

          # stop if we've only one example group
          return if example_groups.keys.length <= 1

          example_groups.each do |loc, hash|
            hash[:average] = hash[:total_time].to_f / hash[:count]
          end

          sorted_groups = example_groups.sort_by {|_, hash| -hash[:average]}.first(number_of_examples)

          output.puts "\nTop #{sorted_groups.size} slowest example groups:"
          sorted_groups.each do |loc, hash|
            average = "#{red(format_seconds(hash[:average]))} #{red("seconds")} average"
            total   = "#{format_seconds(hash[:total_time])} seconds"
            count   = pluralize(hash[:count], "example")
            output.puts "  #{hash[:description]}"
            output.puts cyan("    #{average} (#{total} / #{count}) #{loc}")
          end
        end
      end
    end
  end
end

end
