terraform {
  required_providers {
    schemas = {
      source  = "grafana/schemas"
      version = "0.2.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "2.1.0"
    }
  }
}

provider "grafana" {
  url  = var.GRAFANA_URL
  auth = var.GRAFANA_TOKEN
}