# main.tf
data "azurerm_client_config" "current" {}

data "azurerm_management_group" "target" {
  name = element(split("/", var.management_group_id), length(split("/", var.management_group_id)) - 1)
}

resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "inventory" {
  name                = "law-sn-azure-inventory"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
}

resource "azurerm_user_assigned_identity" "policy" {
  name                = "id-sn-change-tracking-policy"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
}

# Change Tracking DCR
# Note: The exact extension settings can vary by provider version.
# If this fails to produce working inventory, create the DCR once via portal
# (or the CtDcrCreation template) and reference it with a data source instead.
resource "azurerm_monitor_data_collection_rule" "change_tracking" {
  name                = "dcr-change-tracking-sn"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  description         = "Change Tracking and Inventory for ServiceNow SGC"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.inventory.id
      name                   = "law"
    }
  }

  data_flow {
    streams      = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
    destinations = ["law"]
  }

  data_sources {
    extension {
      name           = "CTDataSource-Windows"
      extension_name = "ChangeTracking-Windows"
      streams        = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
    }
    extension {
      name           = "CTDataSource-Linux"
      extension_name = "ChangeTracking-Linux"
      streams        = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
    }
  }

  depends_on = [azurerm_log_analytics_workspace.inventory]
}

# Built-in policies for DCR association
data "azurerm_policy_definition" "ct_windows_dcr" {
  display_name = "Configure Windows Virtual Machines to be associated with a Data Collection Rule for ChangeTracking and Inventory"
}

data "azurerm_policy_definition" "ct_linux_dcr" {
  display_name = "Configure Linux Virtual Machines to be associated with a Data Collection Rule for ChangeTracking and Inventory"
}

resource "azurerm_management_group_policy_assignment" "ct_windows" {
  name                 = "assign-ct-dcr-windows"
  management_group_id  = var.management_group_id
  policy_definition_id = data.azurerm_policy_definition.ct_windows_dcr.id
  display_name         = "Associate Change Tracking DCR - Windows"

  parameters = jsonencode({
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.change_tracking.id
    }
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.policy.id]
  }
}

resource "azurerm_management_group_policy_assignment" "ct_linux" {
  name                 = "assign-ct-dcr-linux"
  management_group_id  = var.management_group_id
  policy_definition_id = data.azurerm_policy_definition.ct_linux_dcr.id
  display_name         = "Associate Change Tracking DCR - Linux"

  parameters = jsonencode({
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.change_tracking.id
    }
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.policy.id]
  }
}

# Roles needed by the policy identity
resource "azurerm_role_assignment" "policy_monitoring_contributor" {
  scope                = var.management_group_id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_user_assigned_identity.policy.principal_id
}

resource "azurerm_role_assignment" "policy_log_analytics_contributor" {
  scope                = azurerm_log_analytics_workspace.inventory.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.policy.principal_id
}

# ServiceNow service principal
resource "azurerm_role_assignment" "sn_log_analytics_reader" {
  scope                = azurerm_log_analytics_workspace.inventory.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = var.servicenow_sp_object_id
}

resource "azurerm_role_assignment" "sn_reader" {
  scope                = var.management_group_id
  role_definition_name = "Reader"
  principal_id         = var.servicenow_sp_object_id
}
