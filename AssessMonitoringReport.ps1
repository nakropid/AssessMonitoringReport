param(
    [string] $DesignatedWorkspaceID = ""
)

#Connect-AzAccount
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

$ReportObject = @()

function Check-Extension {
    param(
        [Parameter(Mandatory=$true)][string] $ExtensionName
    )
    $MMASettings = $($script:Extensions | Where-Object {$_.Name -eq $ExtensionName}).PublicSettings | ConvertFrom-JSON
    if($MMASettings.WorkspaceID) {
        $script:ReportObject = $script:ReportObject + [PSCustomObject]@{
            ResourceType = "Virtual Machine"
            ResourceID = $script:VM.ID
            WorkspaceID = $MMASettings.WorkspaceID
            DesignatedWorkspace = $MMASettings.WorkspaceID -eq $script:DesignatedWorkspaceID
            IncludedTypes = "Defined By Workspace"
            ExcludedTypes = "Defined By Workspace"
        }
    }
    else {
        $script:ReportObject = $script:ReportObject + [PSCustomObject]@{
            ResourceType = "Virtual Machine"
            ResourceID = $script:VM.ID
            WorkspaceID = "None"
            DesignatedWorkspace = $false
            IncludedTypes = "None"
            ExcludedTypes = "All"
        }
    }
}

function Check-DiagnosticSettings {
    param(
        [Parameter(Mandatory=$true)][string] $ResourceType,
        [Parameter(Mandatory=$true)][string] $ResourceID
    )
    $TempReportObject = @()
    $ReportsToLAW = $false
    foreach($DiagnosticSetting in Get-AzDiagnosticSetting -ResourceID $ResourceID) {
        $IncludedTypes = ""
        $ExcludedTypes = ""
        if($DiagnosticSetting.WorkspaceID) {
            $ReportsToLAW = $True
            $WorkspaceID = $script:Workspaces.($DiagnosticSetting.WorkspaceID)
        }
        else {$WorkspaceID = "None"}
        foreach($Metric in $DiagnosticSetting.Metrics) {
            if($Metric.Enabled) {
                if($IncludedTypes -ne "") {$IncludedTypes = $IncludedTypes + ','}
                $IncludedTypes = $IncludedTypes + $Metric.Category
            }
            else{
                if($ExcludedTypes -ne "") {$ExcludedTypes = $ExcludedTypes + ','}
                $ExcludedTypes = $ExcludedTypes + $Metric.Category
            }
        }
        foreach($Log in $DiagnosticSetting.Logs) {
            if($Log.Enabled) {
                if($IncludedTypes -ne "") {$IncludedTypes = $IncludedTypes + ','}
                $IncludedTypes = $IncludedTypes + $Log.Category
            }
            else{
                if($ExcludedTypes -ne "") {$ExcludedTypes = $ExcludedTypes + ','}
                $ExcludedTypes = $ExcludedTypes + $Log.Category
            }
        }
        if($IncludedTypes -eq "") {$IncludedTypes = "None"; $ExcludedTypes = "All"}
        if($ExcludedTypes -eq "") {$IncludedTypes = "All"; $ExcludedTypes = "None"}
        $TempReportObject = $TempReportObject + [PSCustomObject]@{
            ResourceType = $ResourceType
            ResourceID = $ResourceID
            WorkspaceID = $WorkspaceID
            DesignatedWorkspace = $WorkspaceID -eq $script:DesignatedWorkspaceID
            IncludedTypes = $IncludedTypes
            ExcludedTypes = $ExcludedTypes
        }
    }
    if($ReportsToLAW) {$script:ReportObject = $script:ReportObject + $($TempReportObject | Where-Object {$_.WorkspaceID -ne "None"})}
    else {
        $script:ReportObject = $script:ReportObject + [PSCustomObject]@{
            ResourceType = $ResourceType
            ResourceID = $ResourceID
            WorkspaceID = "None"
            DesignatedWorkspace = $false
            IncludedTypes = "None"
            ExcludedTypes = "All"
        }
    }
}

$Workspaces = @{}
foreach($Subscription in Get-AzSubscription -TenantID $(Get-AzContext).Tenant) {
    Set-AzContext -Subscription $Subscription.ID -Tenant $(Get-AzContext).Tenant | Out-Null
    foreach($Workspace in Get-AzOperationalInsightsWorkspace) {
        $Workspaces.($Workspace.ResourceID) = $Workspace.CustomerID
    }
}

foreach($Subscription in Get-AzSubscription -TenantID $(Get-AzContext).Tenant) {
    Set-AzContext -Subscription $Subscription.ID -Tenant $(Get-AzContext).Tenant | Out-Null
    # Assess VM Agent Reporting
    foreach($VM in Get-AzVM) {
        $Extensions = $(Get-AzVMExtension -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name)
        if($Extensions.Name -contains "MicrosoftMonitoringAgent") {Check-Extension "MicrosoftMonitoringAgent"}
        elseif($Extensions.Name -contains "MMAExtension") {Check-Extension "MMAExtension"}
        elseif($Extensions.Name -contains "OMSAgentForLinux") {Check-Extension "OMSAgentForLinux"}
        else {
            $ReportObject = $ReportObject + [PSCustomObject]@{
                ResourceType = "Virtual Machine"
                ResourceID = $VM.ID
                WorkspaceID = "None"
                DesignatedWorkspace = $false
                IncludedTypes = "None"
                ExcludedTypes = "All"
            }
        }
    }
    # Assess Firewall Diagnostic Reporting
    foreach($Firewall in Get-AzFirewall) {Check-DiagnosticSettings -ResourceType "Firewall" -ResourceID $Firewall.ID}
    # Assess Load Balancer Diagnostic Reporting
    foreach($LoadBalancer in Get-AzLoadBalancer) {Check-DiagnosticSettings -ResourceType "Load Balancer" -ResourceID $LoadBalancer.ID}
    # Assess Application Gateway Diagnostic Reporting
    foreach($AppGW in Get-AzApplicationGateway) {Check-DiagnosticSettings -ResourceType "Application Gateway" -ResourceID $AppGW.ID}
    # Assess ExpressRoute Circuit Diagnostic Reporting
    foreach($ERCircuit in Get-AzExpressRouteCircuit) {Check-DiagnosticSettings -ResourceType "ExpressRoute Circuit" -ResourceID $ERCircuit.ID}
}

$ReportObject | ConvertTo-CSV -Delimiter ';' -NoTypeInformation > report.csv
