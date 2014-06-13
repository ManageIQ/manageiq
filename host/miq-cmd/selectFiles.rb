require 'find'
require 'fileutils'
require 'yaml'
require 'ostruct'

require '../../../build_tools/MiqCollectFiles'

fileCollectSpec = [
    {
        :basedir => '../..',
        :todir => 'build_dir',
        :include => [
            "lib/Verbs",
            "lib/metadata",
            "lib/util",
            "lib/disk",
            "lib/fs",
            "lib/encryption",
            "host/miq-cmd/main.rb",
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
        :include => [
            "init.rb"
        ],
    },
]

#cf = MiqCollectFiles.new(fileCollectSpec)
#cf.dumpSpec("collect_files.yaml")
cf = MiqCollectFiles.new("collect_files.yaml")
cf.verbose = true
cf.collect
