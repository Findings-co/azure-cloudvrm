#!/bin/bash

# run the following command to execute this script
# wget -qO- https://raw.githubusercontent.com/Findings-co/azure-cloudvrm/refs/heads/main/azure-setup.sh | bash

# Variables (Replace with your values)
APP_NAME="FindingsCloudVRM"
SECRET_DESC="FindingsCloudVRM"
EXPIRATION="730"

# Check if "--uninstall" parameter is provided
if [[ "$1" == "--uninstall" ]]; then
    # Retrieve Application ID
    APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

    if [[ -z "$APP_ID" ]]; then
        echo "❌ ERROR: No application found with the name '$APP_NAME'. Nothing to delete."
        exit 1
    fi

   echo "✅ Found Application (Client) ID: $APP_ID"

   # Get Service Principal ID
   SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

    # Get Subscription ID
    SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
    echo "✅ Subscription ID: $SUBSCRIPTION_ID"

    # Remove Role Assignment (if exists)
    EXISTING_ROLE=$(az role assignment list --assignee "$APP_ID" --role "Reader" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[0].id" -o tsv)

    if [[ -n "$EXISTING_ROLE" ]]; then
        echo "🛑 Removing role assignment..."
        az role assignment delete --assignee "$APP_ID" --role "Reader" --scope "/subscriptions/$SUBSCRIPTION_ID"
        echo "✅ Role assignment removed."
    else
        echo "⚠️ No existing 'Reader' role assignment found."
   fi

    # Remove Service Principal (if exists)
    if [[ -n "$SP_ID" ]]; then
        echo "🛑 Deleting service principal..."
        az ad sp delete --id "$SP_ID"
        echo "✅ Service principal deleted."
    else
        echo "⚠️ No existing service principal found."
    fi

    # Delete App Registration
    echo "🛑 Deleting application registration..."
    az ad app delete --id "$APP_ID"
    echo "✅ Application registration deleted."

    echo "🚀 Cleanup completed successfully!"

    exit 0
fi

# Check if an app with the same name already exists
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

if [[ -n "$EXISTING_APP_ID" ]]; then
    echo "❌ ERROR: An application with the name '$APP_NAME' already exists."
    echo "Existing Application ID: $EXISTING_APP_ID"
    echo "Use --uninstall to remove current application."
    exit 1
fi

# Create App Registration
echo "✅ Creating a new App Registration: $APP_NAME..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query "appId" -o tsv)

# Retrieve Directory (Tenant) ID
TENANT_ID=$(az account show --query "tenantId" -o tsv)

# Create Service Principal for the App Registration
echo "✅ Creating Service Principal..."
az ad sp create --id "$APP_ID"

# Verify Service Principal Exists
echo "✅ Verifying Service Principal..."
az ad sp list --filter "appId eq '$APP_ID'" --query "[].{id:objectId, appId:appId, displayName:displayName}" -o table

# Create Client Secret
echo "✅ Generating Client Secret..."
SECRET_VALUE=$(az ad app credential reset --id "$APP_ID" --append --query "password" -o tsv)

# Variables (Replace with your app name)
APP_NAME="FindingsCloudVRM"

# Retrieve the Application ID
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

# Ensure APP_ID is not empty
if [[ -z "$APP_ID" ]]; then
    echo "❌ ERROR: Unable to find an application with the name '$APP_NAME'."
    echo "Make sure Step 1 (App Registration) was completed successfully."
    exit 1
fi

# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

# Check if the role assignment already exists
EXISTING_ROLE=$(az role assignment list --assignee "$APP_ID" --role "Reader" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[0].id" -o tsv)

if [[ -n "$EXISTING_ROLE" ]]; then
    echo "❌ ERROR: The 'Reader' role is already assigned to the application ($APP_ID) at the subscription level."
    echo "Existing Role Assignment ID: $EXISTING_ROLE"
    exit 1
fi

# Assign "Reader" role to the registered App at the subscription level
echo "✅ Assigning 'Reader' role to Application ID: $APP_ID..."
az role assignment create --assignee "$APP_ID" --role "Reader" --scope "/subscriptions/$SUBSCRIPTION_ID"

echo "✅ Role assigned successfully!"

# 🎉 Final Summary Printout
echo "====================================="
echo "✅ Setup Completed Successfully!"
echo "✅ Application (client) ID: $APP_ID"
echo "✅ Directory (tenant) ID: $TENANT_ID"
echo "✅ Client secret (value): $SECRET_VALUE"
echo "✅ Subscription ID: $SUBSCRIPTION_ID"
echo "====================================="
