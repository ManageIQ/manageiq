$:.push(File.expand_path("../..", File.dirname(__FILE__)))                      # Add lib/ to path
$:.push(File.expand_path("../../../app/models", File.dirname(__FILE__)))        # Add app/models/ to $LOAD_PATH
$:.push(File.expand_path("../../../app/models/mixins", File.dirname(__FILE__))) # Because app/models/mixins/scanning_mixin requires it without the `mixin` prefix

require File.expand_path("../../../config/boot", File.dirname(__FILE__))
require File.expand_path("../../../config/preinitializer", File.dirname(__FILE__))

require "active_support/core_ext/string/inflections"
require "vmdb/inflections"

Vmdb::Inflections.load_inflections
