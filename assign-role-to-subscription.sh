#!/bin/bash

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

echo "✅ Application ID: $APP_ID"

# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
echo "✅ Subscription ID: $SUBSCRIPTION_ID"

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
echo "✅ Step 2 Completed Successfully!"
echo "✅ Subscription ID: $SUBSCRIPTION_ID"
echo "====================================="
