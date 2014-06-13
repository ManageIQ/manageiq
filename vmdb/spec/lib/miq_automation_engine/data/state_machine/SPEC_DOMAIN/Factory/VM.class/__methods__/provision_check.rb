root = $evm.object("/")
result = $evm.inputs['result']

$evm.log("info", "ProvisionCheck returned <#{result}>")

case result
when 'exception'
  null['ae_result'] = 'exception'
when 'error'
  root['ae_result'] = 'error'
when 'retry'
  root['ae_result']         = 'retry'
  root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  root['ae_result'] = 'ok'
end
