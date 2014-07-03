# TODO: Remove this if build.rb is the only entry-point
require File.join(File.dirname(__FILE__), '1_8_7_hacks')
require_relative 'productization'

require 'erb'
require 'json'
require 'pathname'

module Build
  class KickstartGenerator
    MY_DIR     = Pathname.new(File.dirname(__FILE__)).freeze
    KS_DIR     = MY_DIR.join("kickstarts").freeze
    KS_GEN_DIR = KS_DIR.join("generated").freeze
    KS_FILE    = Productization.file_for("kickstarts/base.ks.erb").freeze

    attr_reader :targets, :puddle, :git_checkout

    def initialize(targets, puddle, git_checkout)
      @targets      = targets
      @puddle       = puddle # used during ERB evaluation
      @git_checkout = git_checkout
    end

    def run(task = :all)
      targets.each do |target|
        @target = target # used during ERB evaluation

        result = evaluate_erb

        write_config(result) if [:all, :config].include?(task)
        write_json(result)   if [:all, :json].include?(task)
      end
    end

    private

    def write_config(result)
      file = KS_GEN_DIR.join("base-#{@target}.cfg")
      $log.info("Writing kickstart in config format: #{file}") if $log
      File.write(file, result)
    end

    def write_json(result)
      json = {
        "install_script"  => result,
        "generate_icicle" => false
      }.to_json

      file = KS_GEN_DIR.join("base-#{@target}.json")
      $log.info("Writing kickstart in json format: #{file}") if $log
      File.write(file, json)
    end

    def evaluate_erb
      ERB.new(File.read(KS_FILE)).result(binding)
    end
  end
end
