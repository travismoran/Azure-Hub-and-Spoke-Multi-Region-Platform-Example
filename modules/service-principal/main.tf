# One Entra application + service principal with a Terraform-rotated client
# secret: the documented exception to the no-secret rule for workloads that
# cannot federate (clusters outside Azure, docs/identity.md §5). Roles are
# assigned by the caller on the target resources; this module only mints the
# principal. The secret lives in state and wherever the caller delivers it.

resource "azuread_application" "this" {
  display_name            = var.display_name
  description             = var.description
  notes                   = "Managed by Terraform (this repo modules/service-principal). Secret lifetime ${var.secret_rotation_days} days, rotated by Terraform."
  owners                  = var.owner_object_ids
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  owners                       = var.owner_object_ids
  app_role_assignment_required = false
  description                  = var.description

  feature_tags {
    hide = true # no sign-in UI; keep it out of My Apps
  }
}

# Replaced once the period has elapsed, which rotates the password on the
# next apply. The old secret stays valid until that apply.
resource "time_rotating" "secret" {
  rotation_days = var.secret_rotation_days
}

resource "azuread_application_password" "this" {
  application_id = azuread_application.this.id
  display_name   = "${var.secret_display_name} (terraform, ${var.secret_rotation_days}d)"
  end_date       = time_rotating.secret.rotation_rfc3339

  rotate_when_changed = {
    rotation = time_rotating.secret.id
  }
}
