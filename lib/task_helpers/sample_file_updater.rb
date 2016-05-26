require 'fileutils'
require 'io/console'

module TaskHelpers
  class SampleFileUpdater
    PROMPT_TO_OVERWRITE = {"config/database.pg.yml" => "config/database.yml"}.freeze
    COPY_IF_NONEXISTENT = {"certs/v2_key.dev"       => "certs/v2_key"}.freeze

    def self.run
      new.run
    end

    def run
      run_nonexistents
      run_prompts unless ENV['MIQ_DISABLE_SAMPLES_PROMPT']
      nil
    end

    private

    def run_prompts
      PROMPT_TO_OVERWRITE.each do |example_path, actual_path|
        example = full_pathname_for(example_path)
        actual  = full_pathname_for(actual_path)

        if File.exist?(actual)
          unless FileUtils.identical?(example, actual)
            puts "Your local copy of '#{actual.basename}' differs from the example ('#{example.basename}')"
            case prompt_overwrite
            when :overwrite
              cp(example, actual, :overwrite => true)
            when :skip
              puts "Ok, skipping..."
            when :skip_all
              puts "Ok, skipping this and all remaining checks..."
              break
            end
          end
        else
          cp(example, actual)
        end
      end
    end

    def prompt_overwrite
      puts "Do you wish to overwrite your copy with the example? (Y)es, (n)o, (S)kip all "
      prompt = STDIN.getch
      puts prompt
      case prompt
      when 'Y'
        :overwrite
      when 'n'
        :skip
      when 'S'
        :skip_all
      else
        puts "Invalid option, try again?"
        prompt_overwrite
      end
    end

    def run_nonexistents
      COPY_IF_NONEXISTENT.each do |example_path, actual_path|
        example = full_pathname_for(example_path)
        actual  = full_pathname_for(actual_path)

        cp(example, actual) unless File.exist?(actual)
      end
    end

    def full_pathname_for(relative_path_from_root)
      Pathname.new(__dir__).expand_path + "../../#{relative_path_from_root}"
    end

    def cp(source, destination, overwrite: false)
      msg = if overwrite
              "Overwriting #{source} with #{destination}..."
            else
              "Copying #{source} to #{destination}..."
            end
      puts msg
      FileUtils.cp(source, destination)
    end
  end
end
