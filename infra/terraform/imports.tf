# Temporary: brings resources created outside Terraform under its control.
# Remove these blocks after the import has been applied.
import {
  to = google_billing_project_info.url_shortener
  id = "projects/project-e985c781-9e31-44bf-bee"
}
import {
  to = google_billing_budget.url_shortener_monthly
  id = "billingAccounts/01E533-A1DBE6-ABB528/budgets/4bd26787-744c-4f64-8eae-4f196a3e5f8a"
}
