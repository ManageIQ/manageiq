type = ARGV.shift
type.constantize.start_worker(*ARGV)
