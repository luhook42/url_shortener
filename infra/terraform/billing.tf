# How this project is paid for, and its monthly budget alert. Imported Nov 10 2026.
# If the project is ever moved to another billing account, terraform plan will now show it.
locals {
  billing_account = "01E533-A1DBE6-ABB528"
}

resource "google_billing_project_info" "url_shortener" {
  project         = "project-e985c781-9e31-44bf-bee"
  billing_account = local.billing_account
}

# Alert-only budget: emails billing admins at these thresholds and never stops anything.
resource "google_billing_budget" "url_shortener_monthly" {
  billing_account = local.billing_account
  display_name    = "url-shortener-monthly"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "35"
    }
  }

  budget_filter {
    calendar_period        = "MONTH"
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
}
