# AssessMonitoringReport

PowerShell-based monitoring assessment report designed to be run on-demand from a local workstation. Evaluates the reported-to Log Analytics Workspace of the appropriate monitoring extension for both Windows and Linux VMs, and the reported-to Log Analytics Workspace and log/metrics types for Azure Firewalls, Load Balancers, Application Gateways, and ExpressRoute Circuits.

## Output

This script outputs a semicolon-delimited CSV file (report.csv) with the following schema:
- ResourceType: The type of Azure resource assessed
- ResourceID: The fully-qualified resource ID of the Azure resource
- WorkspaceID: The GUID of the workspace the Azure resource reports to
- DesignatedWorkspace: A true/false value indicating whether the reported-to workspace matches the input parameter (see Configuration)
- IncludedTypes: The types of metrics and logs forwarded to the Log Analytics Workspace
- ExcludedTypes: The types of metrics and logs not forwarded to the Log Analytics Workspace

Note that each diagnostic setting that reports to a Log Analytics Workspace is listed separately, even if they report to the same workspace. If a resource has one or more diagnostic settings that report to a Log Analytics Workspace, diagnostic settings that do not report to a Log Analytics Workspace are not recorded. If a resource has no diagnostic settings that report to a Log Analytics Workspace, a single entry will be shown indicating same for that resource.

## Prerequisites

The following module is required:
- Az.OperationalInsights

## Configuration

If desired, a "Designated Workspace" can be assigned using the `-DesignatedWorkspaceID` input parameter. This is meant to provide additional assessment functionality if needed, and will indicate on each resource entry if the resource reports to the Designated Workspace.

When executed, the script will prompt the user for login credentials to Azure. The user's default tenant is chosen, and all subscriptions the user has at least Reader access to within that tenant are evaluated.

## To-do

- Existing Azure login detection
- Customization options for output file, tenant selection, resource type selection, subscription filtering, etc.
- Additional resource types?
- Automation-Account friendly version?  
