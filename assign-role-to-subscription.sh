#!/bin/bash

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
