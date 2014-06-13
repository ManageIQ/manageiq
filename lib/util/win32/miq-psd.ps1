param($prefix="http://127.0.0.1:9121/mps/", $miq_log_dir=$null)

function Main($prefix)
{
	# create an httplistener listening on the specified prefix url
	$listener = new-object Net.HttpListener
	$listener.Prefixes.Add($prefix)
	trap {logger "Error: $_" "ERROR"; send_error_object $writer $_; break}
	$listener.Start()
	logger "Process [$($pid)] listening on [$($prefix)]"

	# loop, accepting synchronous requests until we're told to quit
	$shouldProcess = $true

	while ($shouldProcess) {
		trap {logger "Error: $error" "ERROR"; send_error_object $writer $error[0]; continue}

		$ctx = $listener.GetContext(); $response = $ctx.Response
		$response_start_time = Get-Date

		# we'll write out a simple text response
		$response.Headers.Add("Content-Type","text/plain")
		$writer = new-object IO.StreamWriter($response.OutputStream,[Text.Encoding]::UTF8)

		# see if there is a cmd query string..
		$request = $ctx.Request; $cmd = $request.QueryString["cmd"]; Write-debug "Request1:[$($cmd)]"

		# Comment out the following line to test sending plain text strings through the URL
		$cmd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cmd))
		log_header "Processing request (for $($request.RemoteEndPoint) at $((Get-Date).GetDateTimeFormats()[114]))`n$($cmd)"

		switch ($cmd) {
			"quit" {send_object $writer $pid; $shouldProcess=$false; break}
			$null  {send_null $writer; break}
			default {
				& {
					$error.clear(); $miq_lines_count=0;
					invoke-expression $cmd | out-string -stream | foreach {$writer.WriteLine($_.TrimEnd()); $miq_lines_count++}
					if ($miq_lines_count -eq 0) {send_null $writer}
				}
			}
		}
		$writer.Close();
		logger "Completed in $(((Get-Date) - $response_start_time).TotalSeconds)"
		[GC]::Collect()
	}
	logger "*** Stopping"; $listener.Stop()
}

$global:miq_log_array = @()
function send_object($writer, $object) {$object | convertto-xml -as String | foreach {$writer.WriteLine($_.TrimEnd())}}
function send_error_object($writer, $object) {$object | convertto-xml -as Stream -Depth 4 | foreach {$writer.WriteLine($_.TrimEnd())}}
function send_null($writer) {send_object $writer $null}

function global:miq_logger($level, $msg) {
  if ($msg -eq $null) {$level, $msg = $level};
  $miq_logger_date = Get-Date
  $global:miq_log_array += $log_data = @{"level"=$level; "msg"=$msg; "date"=$miq_logger_date.GetDateTimeFormats()[114]}
  if ($miq_log_dir -ne $null) {
    Set-Content (Join-Path $miq_log_dir "$($PID)_$($miq_logger_date.ToFileTime()).log") "$($level[0]), [$($miq_logger_date.GetDateTimeFormats()[114]) #$($pid)]  $($level) -- : $($msg)"
  }
}
function logger($msg, $level="INFO ") {Write-Host "[----] $($level[0]), [$((Get-Date).GetDateTimeFormats()[114]) #$($pid)]  $($level) -- : $($msg)"}
function log_header($msg) {Write-Host "`n$($msg)"}
function global:log_memory($level, $msg) {miq_logger $level "$($msg) - Working Set: $([System.Math]::Round((Get-Process -Id $PID).WorkingSet / 1MB, 2)) MB"}

$ErrorActionPreference = "SilentlyContinue"
. Main $prefix
logger "*** Complete"