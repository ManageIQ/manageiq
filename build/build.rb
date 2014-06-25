require File.join(File.dirname(__FILE__), '1_8_7_hacks')
require 'pathname'
require 'fileutils'
require 'logger'
require 'pathname'
require 'yaml'

require_relative 'productization'
require_relative 'kickstart_generator'
require_relative 'git_checkout'

$log = Logger.new(STDOUT)

puddle = nil
arg = ARGV[0].to_s.strip.downcase
case arg
when "nightly"
  build_label = "nightly"
when ""
  build_label = "test"
else
  puddle = build_label = arg
end

targets_file = Build::Productization.file_for("config/targets.yml")
tdl_file     = Build::Productization.file_for("config/base.tdl")
ova_file     = Build::Productization.file_for("config/ova.json")
$log.info "Using inputs: puddle: #{puddle}, build_label: #{build_label}, targets_file: #{targets_file}"
$log.info "              tdl_file: #{tdl_file}, ova_file: #{ova_file}."

def verify_run(output)
  if output =~ /UUID: (.*)/
    Regexp.last_match[1]
  else
    $log.error("Could not find UUID.")
    exit 1
  end
end

YEAR_MONTH_DAY = Time.now.strftime("%Y%m%d")
HOUR_MINUTE    = Time.now.strftime("%H%M")
timestamp      = "#{YEAR_MONTH_DAY}#{HOUR_MINUTE}"

targets_config                 = YAML.load_file(targets_file)
name, directory, repo, targets = targets_config.values_at("name", "directory", "repository", "targets")
git_checkout                   = Build::GitCheckout.new(repo)
Build::KickstartGenerator.new(targets.keys, puddle, git_checkout).run

FILE_TYPE = {
  'vsphere'       => 'ova',
  'rhevm'         => 'ova',
  'openstack-kvm' => 'qc2'
}

BASE_DIRECTORY        = Pathname.new("/var/www/html/cfme")
STREAM_DIRECTORY      = BASE_DIRECTORY.join(directory)
DESTINATION_DIRECTORY = STREAM_DIRECTORY.join(build_label == "test" ? "test" : YEAR_MONTH_DAY)
FileUtils.mkdir_p(DESTINATION_DIRECTORY)

Dir.chdir("/root/src/imagefactory") do
  targets.sort.reverse.each do |target, imgfac_target|
    $log.info "Building for #{target}:"

    input_file  = Build::KickstartGenerator::KS_GEN_DIR.join("base-#{target}.json")

    output_file = Build::KickstartGenerator::KS_GEN_DIR.join("base-#{target}-#{build_label}-#{timestamp}.json")
    FileUtils.cp(input_file, output_file)
    $log.info "Running base_image using parameters: kickstart: #{output_file} copied from #{input_file}. tdl: #{tdl_file}."
    output = `./imagefactory --debug base_image --parameters #{output_file} #{tdl_file}`
    uuid   = verify_run(output)
    $log.info "#{target} base_image complete, uuid: #{uuid}"

    $log.info "Running #{target} target_image with #{imgfac_target} and uuid: #{uuid}"
    output = `./imagefactory --debug target_image #{imgfac_target} --id #{uuid}`
    uuid   = verify_run(output)
    $log.info "#{target} target_image with imgfac_target: #{imgfac_target} and uuid #{uuid} complete"

    unless imgfac_target == "openstack-kvm"
      $log.info "Running #{target} target_image ova with ova file: #{ova_file} and uuid: #{uuid}"
      output = `./imagefactory --debug target_image ova --parameters #{ova_file} --id #{uuid}`
      uuid   = verify_run(output)
      $log.info "#{target} target_image ova with uuid: #{uuid} complete"
    end
    $log.info "Built #{target} with final UUID: #{uuid}"
    source      = "/var/lib/imagefactory/storage/#{uuid}.body"

    file_name = "#{name}-#{target}-#{build_label}-#{timestamp}-#{git_checkout.commit_sha}.#{FILE_TYPE[imgfac_target]}"
    destination = DESTINATION_DIRECTORY.join(file_name)
    $log.info `mv  #{source} #{destination}`
  end
end

# Only update the symlink for a nightly
unless build_label == "test"
  link = STREAM_DIRECTORY.join("latest")
  if File.exist?(link)
    raise "#{link} is not a symlink!" unless File.symlink?(link)
    result = FileUtils.rm(link, :verbose => true)
    $log.info("Deleted symlink: #{result}")
  end

  result = FileUtils.ln_s(DESTINATION_DIRECTORY, link, :verbose => true)
  $log.info("Created symlink: #{result}")
end
