#!/usr/bin/env bash
#
# Register the Azure resource providers this platform needs, in every
# subscription it deploys into. Idempotent; safe to re-run. Needed because
# live/root.hcl sets resource_provider_registrations = "none" (the provider
# never registers anything on its own, which keeps plans fast and explicit).
#
# Reads the same env vars as terragrunt (source your .env first):
#   ARM_SUBSCRIPTION_ID, TG_SUBSCRIPTION_MANAGEMENT, TG_SUBSCRIPTION_CONNECTIVITY,
#   TG_SUBSCRIPTION_<ENV>  (TG_SUBSCRIPTION_DEV, TG_SUBSCRIPTION_PROD, ...)
# Empty / unset ones are skipped; duplicates are registered once.
#
# Also opts every subscription out of Network Watcher auto-creation
# (Microsoft.Network/DisableNetworkWatcherAutocreation). Without it Azure
# creates NetworkWatcherRG/NetworkWatcher_<region> the moment the first VNet
# lands in a region; those resources are free but live outside Terraform
# state, so `destroy` leaves them behind. Any watcher we want is created
# explicitly by a module behind a toggle. Set SKIP_NETWORK_WATCHER_OPT_OUT=1
# to keep Azure's default behaviour. The feature takes effect only after
# Microsoft.Network is (re-)registered once the feature shows "Registered",
# which the script does automatically; re-run it if the first pass reports
# the feature as still "Registering".
#
# Cost: none. Registration takes a minute or two per namespace; the script
# does not wait (terragrunt plans will succeed once "Registered").

set -euo pipefail

NAMESPACES=(
  Microsoft.Compute
  Microsoft.ContainerRegistry
  Microsoft.ContainerService
  Microsoft.Insights
  Microsoft.KeyVault
  Microsoft.ManagedIdentity
  Microsoft.Network
  Microsoft.OperationalInsights
  Microsoft.OperationsManagement
  Microsoft.PolicyInsights
  Microsoft.Quota
  Microsoft.Security
  Microsoft.Storage
)

mapfile -t SUBS < <(env | grep -E '^(ARM_SUBSCRIPTION_ID|TG_SUBSCRIPTION_[A-Z0-9_]+)=' | cut -d= -f2- | grep -v '^$' | sort -u)
if [[ ${#SUBS[@]} -eq 0 ]]; then
  echo "No ARM_SUBSCRIPTION_ID / TG_SUBSCRIPTION_* set - source your .env first." >&2
  exit 1
fi

for sub in "${SUBS[@]}"; do
  name=$(az account show --subscription "$sub" --query name -o tsv)
  echo ">> ${name}"
  for ns in "${NAMESPACES[@]}"; do
    state=$(az provider show --subscription "$sub" --namespace "$ns" --query registrationState -o tsv 2>/dev/null || echo "Unknown")
    if [[ "$state" == "Registered" ]]; then
      echo "   ${ns}: already registered"
    else
      az provider register --subscription "$sub" --namespace "$ns" --output none 2>/dev/null
      echo "   ${ns}: registering"
    fi
  done

  if [[ "${SKIP_NETWORK_WATCHER_OPT_OUT:-0}" == "1" ]]; then
    echo "   Network Watcher auto-creation opt-out: skipped (SKIP_NETWORK_WATCHER_OPT_OUT=1)"
    continue
  fi
  feature="DisableNetworkWatcherAutocreation"
  fstate=$(az feature show --subscription "$sub" --namespace Microsoft.Network --name "$feature" --query properties.state -o tsv 2>/dev/null || echo "NotRegistered")
  case "$fstate" in
    Registered)
      # The feature only applies after the provider is re-registered.
      az provider register --subscription "$sub" --namespace Microsoft.Network --output none 2>/dev/null
      echo "   ${feature}: registered (Microsoft.Network re-registered to apply it)"
      ;;
    Registering|Pending)
      echo "   ${feature}: ${fstate} - re-run this script in a few minutes to apply it"
      ;;
    *)
      az feature register --subscription "$sub" --namespace Microsoft.Network --name "$feature" --output none 2>/dev/null
      echo "   ${feature}: registering - re-run this script in a few minutes to apply it"
      ;;
  esac
done
