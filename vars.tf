variable "GRAFANA_URL" {
  type        = string
  description = "Fully qualified domain name of your Grafana instance."
}

variable "GRAFANA_TOKEN" {
  type        = string
  description = "Basic auth password or API token."
}