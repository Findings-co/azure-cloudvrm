#!/bin/bash

# Variables (Replace with your values)
APP_NAME="FindingsCloudVRM"
SECRET_DESC="FindingsCloudVRM"
EXPIRATION="730"

# Check if an app with the same name already exists
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

if [[ -n "$EXISTING_APP_ID" ]]; then
    echo "❌ ERROR: An application with the name '$APP_NAME' already exists."
    echo "Existing Application ID: $EXISTING_APP_ID"
    exit 1
fi

# Create App Registration
echo "✅ Creating a new App Registration: $APP_NAME..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query "appId" -o tsv)

# Retrieve Directory (Tenant) ID
TENANT_ID=$(az account show --query "tenantId" -o tsv)

echo "✅ Application (Client) ID: $APP_ID"
echo "✅ Directory (Tenant) ID: $TENANT_ID"

# Create Service Principal for the App Registration
echo "✅ Creating Service Principal..."
az ad sp create --id "$APP_ID"

# Verify Service Principal Exists
echo "✅ Verifying Service Principal..."
az ad sp list --filter "appId eq '$APP_ID'" --query "[].{id:objectId, appId:appId, displayName:displayName}" -o table

# Create Client Secret
echo "✅ Generating Client Secret..."
SECRET_VALUE=$(az ad app credential reset --id "$APP_ID" --append --query "password" -o tsv)

echo "✅ Client Secret Value: $SECRET_VALUE"
echo "⚠️ Save the Client Secret Value securely, as it cannot be retrieved later!"

