#!/bin/bash

# run the following command to execute this script
# wget -qO- https://raw.githubusercontent.com/Findings-co/azure-cloudvrm/refs/heads/main/azure-setup.sh | bash

# Check for required dependencies.
command -v az >/dev/null || { echo "Error: Azure CLI is not installed."; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is not installed."; exit 1; }

# Default values
BASE_APP_NAME="FindingsCloudVRM"
APP_NAME=""
SUBSCRIPTION_ID=""
UNINSTALL=false
PARAMS_PROVIDED=false

function usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --app-name APP_NAME            Specify the Azure App Registration name"
    echo "  --subscription-id ID           Specify the Azure Subscription ID"
    echo "  --uninstall                    Uninstall the specified app (requires --app-name)"
    echo "  --help, -h                     Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --app-name)
            if [[ $# -lt 2 ]]; then
                echo "Error: --app-name requires an argument."
                usage
                exit 1
            fi
            APP_NAME="$2"
            PARAMS_PROVIDED=true
            shift 2
            ;;
        --subscription-id)
            if [[ $# -lt 2 ]]; then
                echo "Error: --subscription-id requires an argument."
                usage
                exit 1
            fi
            SUBSCRIPTION_ID="$2"
            PARAMS_PROVIDED=true
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            PARAMS_PROVIDED=true
            shift 1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            exit 1
            ;;
    esac
done

function check_app_exists() {
    az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv | grep -q .
}

function uninstall_app() {
    if [[ -z "$APP_NAME" ]]; then
        echo "❌ ERROR: --uninstall requires --app-name to specify which app to remove."
        usage
        exit 1
    fi

    APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

    if [[ -z "$APP_ID" ]]; then
        echo "❌ ERROR: No application found with the name '$APP_NAME'. Nothing to delete."
        exit 1
    fi

    echo "✅ Found Application (Client) ID: $APP_ID"

    # Get Service Principal ID
    SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

    # Remove Role Assignment (if exists)
    EXISTING_ROLE=$(az role assignment list --assignee "$APP_ID" --query "[0].id" -o tsv)
    if [[ -n "$EXISTING_ROLE" ]]; then
        echo "🛑 Removing role assignment..."
        az role assignment delete --assignee "$APP_ID"
        echo "✅ Role assignment removed."
    else
        echo "⚠️ No existing role assignment found."
    fi

    # Remove Service Principal
    if [[ -n "$SP_ID" ]]; then
        echo "🛑 Deleting service principal..."
        az ad sp delete --id "$SP_ID"
        echo "✅ Service principal deleted."
    fi

    # Delete App Registration
    echo "🛑 Deleting application registration..."
    az ad app delete --id "$APP_ID"
    echo "✅ Application registration deleted."

    # Remove Custom Role
    CUSTOM_ROLE_NAME="${APP_NAME}Role"
    EXISTING_CUSTOM_ROLE=$(az role definition list --name "$CUSTOM_ROLE_NAME" --query "[].name" -o tsv)
    if [[ -n "$EXISTING_CUSTOM_ROLE" ]]; then
        echo "🛑 Deleting custom role: $CUSTOM_ROLE_NAME..."
        az role definition delete --name "$CUSTOM_ROLE_NAME"
        echo "✅ Custom role deleted."
    fi

    echo "🚀 Cleanup completed successfully!"
    exit 0
}

function install_app() {
    # If APP_NAME is empty (not provided via --app-name), generate a unique one
    if [[ -z "$APP_NAME" ]]; then
        APP_NAME="${BASE_APP_NAME}-$(tr -dc 'a-zA-Z' </dev/urandom | fold -w 5 | head -n 1)"
    fi

    # Check for existing application
    if check_app_exists; then
        echo "❌ ERROR: An application with the name '$APP_NAME' already exists."
        echo "Use --uninstall to remove the current application."
        exit 1
    fi

    # Get Subscription ID if not provided
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
    fi

    # Create App Registration
    echo "✅ Creating a new App Registration: $APP_NAME..."
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query "appId" -o tsv)

    # Retrieve Tenant ID
    TENANT_ID=$(az account show --query "tenantId" -o tsv)

    # Create Service Principal
    echo "✅ Creating Service Principal..."
    az ad sp create --id "$APP_ID"

    # Create Client Secret
    echo "✅ Generating Client Secret..."
    SECRET_VALUE=$(az ad app credential reset --id "$APP_ID" --append --query "password" -o tsv)

    # Define Custom Role JSON
    CUSTOM_ROLE_NAME="${APP_NAME}Role"
    CUSTOM_ROLE_JSON=$(cat <<EOF
{
    "Name": "$CUSTOM_ROLE_NAME",
    "Description": "Custom role with read-only access",
    "Actions": [        
       "Microsoft.PolicyInsights/*/read",
       "Microsoft.ResourceGraph/*/read",
       "Microsoft.Authorization/*/read",
       "Microsoft.Security/*/read"
    ],
    "AssignableScopes": [
        "/subscriptions/$SUBSCRIPTION_ID"
    ]
}
EOF
)

    # Save JSON to a temp file
    CUSTOM_ROLE_FILE="/tmp/custom_role.json"
    echo "$CUSTOM_ROLE_JSON" > "$CUSTOM_ROLE_FILE"

    # Create the custom role
    echo "✅ Creating a custom role: $CUSTOM_ROLE_NAME..."
    az role definition create --role-definition "$CUSTOM_ROLE_FILE"

    # Assign the custom role to the application
    echo "✅ Assigning custom role to Application ID: $APP_ID..."
    az role assignment create --assignee "$APP_ID" --role "$CUSTOM_ROLE_NAME" --scope "/subscriptions/$SUBSCRIPTION_ID"

    # Cleanup temp file
    rm -f "$CUSTOM_ROLE_FILE"

    # 🎉 Final Summary Printout
    echo "====================================="
    echo "✅ Setup Completed Successfully!"
    echo "✅ Application (client) ID: $APP_ID"
    echo "✅ Directory (tenant) ID: $TENANT_ID"
    echo "✅ Client secret (value): $SECRET_VALUE"
    echo "✅ Subscription ID: $SUBSCRIPTION_ID"
    echo "✅ Application Name: ${APP_NAME}"
    echo "====================================="
}

# Main logic
if [[ "$UNINSTALL" == true ]]; then
    if [[ -z "$APP_NAME" ]]; then
        echo "❌ ERROR: --uninstall requires --app-name to specify which app to remove."
        usage
        exit 1
    fi
    uninstall_app
    exit 0
fi

install_app
