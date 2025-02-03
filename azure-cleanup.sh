#!/bin/bash

# Variables (Replace with your app name)
APP_NAME="FindingsCloudVRM"

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
