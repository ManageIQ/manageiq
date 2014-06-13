If WScript.Arguments.Count = 1 Then
  cmdStr = WScript.Arguments.Item(0)
Elseif WScript.Arguments.Count = 2 Then
  cmdStr = WScript.Arguments.Item(0)
  vmName = WScript.Arguments.Item(1)
Else
  WScript.Quit
End If

Set objVirtualServer = CreateObject("VirtualServer.Application")

If cmdStr = "-l" Then
  For Each objVirtualMachine in objVirtualServer.VirtualMachines
   WScript.Echo objVirtualMachine.File
  Next
  WScript.Quit
End If

If cmdStr = "-v" Then
  WScript.Echo "Microsoft Virtual_Server " & objVirtualServer.Version
  WScript.Quit
End If


Set objVirtualMachine = objVirtualServer.FindVirtualMachine(vmName)
If cmdStr = "state" Then
  WScript.Echo objVirtualMachine.State
Elseif cmdStr = "start" Then
  objVirtualMachine.Startup
Elseif cmdStr = "stop" Then
  If objVirtualMachine.GuestOS.CanShutdown = true Then
    objVirtualMachine.GuestOS.Shutdown
  Else
    objVirtualMachine.TurnOff
  End If
Elseif cmdStr = "suspend" Then
  objVirtualMachine.Save
Elseif cmdStr = "reset" Then
  objVirtualMachine.Reset
Elseif cmdStr = "pause" Then
  objVirtualMachine.Pause
Elseif cmdStr = "resume" Then
  objVirtualMachine.Resume
End If
