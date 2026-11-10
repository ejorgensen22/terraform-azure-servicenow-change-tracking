# Terraform: Azure Change Tracking + Inventory for ServiceNow SGC

Complete Terraform example that enables **Azure Change Tracking and Inventory** (via Data Collection Rules and Azure Policy) so the ServiceNow **Service Graph Connector for Azure** can collect installed software (including database packages) from VMs.

This approach does **not** require Azure Run Command permissions.

## What it creates

- Resource group
- Log Analytics workspace
- User-assigned managed identity (for policy assignments)
- Change Tracking Data Collection Rule
- Policy assignments at management group scope (Windows + Linux) that associate the DCR to VMs
- Role assignments for:
  - The policy identity (`Monitoring Contributor`, `Log Analytics Contributor`)
  - The ServiceNow service principal (`Log Analytics Reader`, `Reader`)

## Usage

1. Provide values for the variables (see `variables.tf`):
   - `resource_group_name`
   - `management_group_id` (full resource ID)
   - `servicenow_sp_object_id`
   - Optionally override `location` and retention

2. Run:

```bash
terraform init
terraform plan
terraform apply
```

3. After the first apply, create a **remediation task** for the policy assignments so existing VMs are onboarded (portal or `azurerm_policy_remediation`).

4. In ServiceNow, point the Azure Service Graph Connector software / Log Analytics connection at the workspace created here.

## Notes

- The Change Tracking DCR schema can be sensitive to the azurerm provider version. If inventory data does not appear after association, create the DCR once via the Azure portal (or the official CtDcrCreation template) and reference the existing resource with a data source.
- Confirm the exact `display_name` of the built-in policies in your tenant if the data sources fail to resolve.
- For multiple management groups, convert the policy assignment resources to use `for_each`.
- This gives installed-software visibility. Running processes / TCP connections require additional configuration (VM Insights or Run Command).

## License

Example code — use and adapt as needed.
