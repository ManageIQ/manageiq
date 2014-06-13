# Abstract RHEVM Error Class
class RhevmApiError < StandardError; end

# Existence
class RhevmApiTemplateAlreadyExists < RhevmApiError; end
class RhevmApiVmAlreadyExists       < RhevmApiError; end

# Power State
class RhevmApiVmAlreadyRunning < RhevmApiError; end
class RhevmApiVmIsNotRunning   < RhevmApiError; end
class RhevmApiVmNotReadyToBoot < RhevmApiError; end