# Loading config and utils

. "C:\OpenStack\hyperv-compute-ci\HyperV\scripts\config.ps1"
. "C:\OpenStack\hyperv-compute-ci\HyperV\scripts\utils.ps1"


if (Test-Path $eventlogPath){
	Remove-Item $eventlogPath -recurse -force
}

New-Item -ItemType Directory -Force -Path $eventlogPath


dumpeventlog $eventlogPath
exporthtmleventlog $eventlogPath

