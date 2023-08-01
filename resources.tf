data "schemas_core_dashboard" "example" {
  title = "Terraform example"
  description = "Example dashboard built with Terraform"
}

resource "grafana_dashboard" "example" {
  config_json = data.schemas_core_dashboard.example.rendered_json
}