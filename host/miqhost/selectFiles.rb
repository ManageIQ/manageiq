require 'find'
require 'fileutils'
require 'yaml'
require 'ostruct'

require '../../../build_tools/MiqCollectFiles'

fileCollectSpec = [
    {
        :basedir => '../..',
        :todir => 'build_dir',
        :dirs => [
            "lib/Verbs",
            "lib/metadata",
            "lib/util",
            "lib/disk",
            "lib/fs",
            "lib/encryption",
            "host/miqhost/miqhost.rb",
            "host/miqhost/expose_services.rb",
            "host/miqhost/MiqHostConfig.rb",
            "host/miqhost/process_queue.rb",
            "host/miqhost/heartbeat.rb",
        ],
        :exclude => [
            /\/\.svn/,
            /~$/,
            /\/NTFSCPP/,
            /\.c$/,
            /\.h$/,
            /\.o$/,
            /dos_mbr.img$/,
            /test.rb$/,
            /\/rdoc$/,
            /\/examples$/,
            /\/doc$/,
            /\/miqCryptInit.rb$/,
        ],
        :encrypt => [
            /\.rb$/,
        ],
        :noencrypt => [
            /\/encryption\//,
        ],
    },
    {
        :basedir => ".",
        :todir => 'build_dir',
        :dirs => nil,
        :files => [
            "init.rb"
        ],
    },
]

#cf = MiqCollectFiles.new(fileCollectSpec)
#cf.dumpSpec("collect_files.yaml")
cf = MiqCollectFiles.new(ARGV[0])
cf.verbose = true
cf.collect
