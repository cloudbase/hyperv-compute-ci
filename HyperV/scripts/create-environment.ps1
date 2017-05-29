Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/compute-hyperv',
    [string]$isDebug='no'
)

if ($isDebug -eq  'yes') {
    Write-Host "Debug info:"
    Write-Host "devstackIP: $devstackIP"
    Write-Host "branchName: $branchName"
    Write-Host "buildFor: $buildFor"
}

$projectName = $buildFor.split('/')[-1]

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"

$hasProject = Test-Path $buildDir\$projectName
$hasNova = Test-Path $buildDir\nova
$hasNeutron = Test-Path $buildDir\neutron
$hasNeutronTemplate = Test-Path $neutronTemplate
$hasNovaTemplate = Test-Path $novaTemplate
$hasConfigDir = Test-Path $configDir
$hasBinDir = Test-Path $binDir
$hasMkisoFs = Test-Path $binDir\mkisofs.exe
$hasQemuImg = Test-Path $binDir\qemu-img.exe
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pip_conf_content = @"
[global]
index-url = http://10.20.1.8:8080/cloudbase/CI/+simple/
[install]
trusted-host = 10.20.1.8
"@

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Write-Host "Ensuring nova-compute and neutron services are stopped."
Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

destroy_planned_vms

Write-Host "Stopping any possible python processes left."
Stop-Process -Name python -Force

if (Get-Process -Name nova-compute){
    Throw "Hyperv-Compute is still running on this host"
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}

$ErrorActionPreference = "Stop"

if (-not (Get-Service neutron-hyperv-agent -ErrorAction SilentlyContinue))
{
    Throw "Neutron Hyper-V Agent Service not registered"
}

if (-not (get-service nova-compute -ErrorAction SilentlyContinue))
{
    Throw "Nova Service not registered"
}

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}

Write-Host "Cleaning up the config folder."
if ($hasConfigDir -eq $false) {
    mkdir $configDir
}else{
    Try
    {
        Remove-Item -Recurse -Force $configDir\*
    }
    Catch
    {
        Throw "Can not clean the config folder"
    }
}

if ($hasProject -eq $false){
    Get-ChildItem $buildDir
    Get-ChildItem ( Get-Item $buildDir ).Parent.FullName
    Throw "$projectName repository was not found. Please run gerrit-git-prep.sh for this project first"
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    Invoke-WebRequest -Uri "http://10.20.1.14:8080/openstack_bin.zip" -OutFile "$bindir\openstack_bin.zip"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$bindir\openstack_bin.zip", "$bindir")
    Remove-Item -Force "$bindir\openstack_bin.zip"
}

if ($hasNovaTemplate -eq $false){
    Throw "Nova template not found"
}

if ($hasNeutronTemplate -eq $false){
    Throw "Neutron template not found"
}

git config --global user.email "hyper-v_ci@microsoft.com"
git config --global user.name "Hyper-V CI"

if ($isDebug -eq  'yes') {
    Write-Host "Status of $buildDir before GitClonePull"
    Get-ChildItem $buildDir
}

if ($buildFor -eq "openstack/compute-hyperv") {
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://git.openstack.org/openstack/neutron.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://git.openstack.org/openstack/nova.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\networking-hyperv" "https://git.openstack.org/openstack/networking-hyperv.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\requirements" "https://git.openstack.org/openstack/requirements.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\os-win" "https://git.openstack.org/openstack/os-win.git" $branchName
    }
    Get-ChildItem $buildDir
}

else {
    Throw "Cannot build for project: $buildFor"
}

$hasLogDir = Test-Path $openstackLogs
if ($hasLogDir -eq $false){
    mkdir $openstackLogs
}

pushd C:\
if (Test-Path $pythonArchive)
{
    Remove-Item -Force $pythonArchive
}
Invoke-WebRequest -Uri http://10.20.1.14:8080/python.zip -OutFile $pythonArchive

if (Test-Path $pythonDir)
{
    Remove-Item -Recurse -Force $pythonDir
}
Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\$pythonArchive", "C:\")

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

$ErrorActionPreference = "Continue"
& easy_install -U pip
& pip install -U setuptools
& pip install -U --pre PyMI
& pip install cffi
& pip install numpy
& pip install pycrypto
$ErrorActionPreference = "Stop"

popd

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

cp $templateDir\distutils.cfg C:\Python27\Lib\distutils\distutils.cfg

if ($isDebug -eq  'yes') {
    Write-Host "BuildDir is: $buildDir"
    Write-Host "ProjectName is: $projectName"
    Write-Host "Listing $buildDir parent directory:"
    Get-ChildItem ( Get-Item $buildDir ).Parent.FullName
    Write-Host "Listing $buildDir before install"
    Get-ChildItem $buildDir
}

ExecRetry {
    pushd "$buildDir\requirements"
    Write-Host "Installing OpenStack/Requirements..."
    & pip install -c upper-constraints.txt -U pbr virtualenv httplib2 prettytable>=0.7 setuptools
    & pip install -c upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install openstack/requirements from repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\neutron"
        Get-ChildItem $buildDir\neutron
    }
    pushd $buildDir\neutron
    Write-Host "Installing openstack/neutron..."
    git fetch git://git.openstack.org/openstack/neutron refs/changes/33/468833/1
    cherry_pick FETCH_HEAD
    & update-requirements.exe --source $buildDir\requirements .
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install neutron from repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\networking-hyperv:"
        Get-ChildItem $buildDir\networking-hyperv
    }
    pushd $buildDir\networking-hyperv
    Write-Host "Installing openstack/networking-hyperv..."
    & update-requirements.exe --source $buildDir\requirements .
    if (($branchName -eq 'stable/liberty') -or ($branchName -eq 'stable/mitaka')) {
        & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    } else {
        & pip install -e $buildDir\networking-hyperv
    }
    if ($LastExitCode) { Throw "Failed to install networking-hyperv from repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\nova"
        Get-ChildItem $buildDir\nova
    }
    Write-Host "Installing openstack/nova..."
    pushd $buildDir\nova
    & update-requirements.exe --source $buildDir\requirements .
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install nova fom repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\compute-hyperv"
        Get-ChildItem $buildDir\compute-hyperv
    }
    pushd $buildDir\compute-hyperv

    git fetch git://git.openstack.org/openstack/compute-hyperv refs/changes/70/467370/1
    cherry_pick FETCH_HEAD

    Write-Host "Installing openstack/compute-hyperv..."
    & update-requirements.exe --source $buildDir\requirements .
    if (($branchName -eq 'stable/liberty') -or ($branchName -eq 'stable/mitaka')) {
        & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    } else {
        & pip install -c $buildDir\requirements\upper-constraints.txt -e .
    }
    if ($LastExitCode) { Throw "Failed to install Hyperv-Compute fom repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\os-win"
        Get-ChildItem $buildDir\os-win
    }
    pushd $buildDir\os-win
    Write-Host "Installing openstack/os-win..."
    & update-requirements.exe --source $buildDir\requirements .
    # only install os-win on stable/mitaka, stable/newton, or master.
    & pip install .
    if ($LastExitCode) { Throw "Failed to install os-win fom repo" }
    popd
}

if ($branchName -eq 'master') {
    pip install setuptools==33.1.1 oslo.log==3.23.0 amqp==2.1.3 kombu==4.0.1
}

$cpu_array = ([array](gwmi -class Win32_Processor))
$cores_count = $cpu_array.count * $cpu_array[0].NumberOfCores
$novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$openstackLogs").Replace('[RABBITUSER]', $rabbitUser)
$neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$openstackLogs").Replace('[RABBITUSER]', $rabbitUser).replace('[CORES_COUNT]', "$cores_count")

if (@("stable/newton", "stable/ocata", "master") -contains $branchName.ToLower()) {
    $novaConfig = $novaConfig.replace('hyperv.nova.driver.HyperVDriver', 'compute_hyperv.driver.HyperVDriver')
}

Set-Content $configDir\nova.conf $novaConfig
if ($? -eq $false){
    Throw "Error writting $configDir\nova.conf"
}

Set-Content $configDir\neutron_hyperv_agent.conf $neutronConfig
if ($? -eq $false){
    Throw "Error writting $configDir\neutron_hyperv_agent.conf"
}

cp "$templateDir\policy.json" "$configDir\"
cp "$templateDir\interfaces.template" "$configDir\"

$hasNovaExec = Test-Path "$pythonScripts\nova-compute.exe"
if ($hasNovaExec -eq $false){
    Throw "No nova-compute.exe found"
}

$hasNeutronExec = Test-Path "$pythonScripts\neutron-hyperv-agent.exe"
if ($hasNeutronExec -eq $false){
    Throw "No neutron-hyperv-agent.exe found"
}

Write-Host "Done building env"
