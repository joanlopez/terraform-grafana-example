# Terraform Grafana example

## Looking for building your own example?

**If you're a [learning-by-doing](https://en.wikipedia.org/wiki/Learning-by-doing) kind of person,** you can follow the steps below to build your own example.

### Pre-requisites

First of all, you need to have these tools up and running before starting:

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Terraform Cloud](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions) (*to store `.tfstate` files*)
  - Alternatively, you can use any [Remote State](https://developer.hashicorp.com/terraform/language/state/remote) backend.
  - Please, bear in mind that [you should not store `.tfstate` files locally in your repository](https://jhooq.com/terraform-do-not-store-tfstate-in-git/).
- [Grafana Cloud](https://grafana.com/products/cloud/) instance (*with a [service account token](https://grafana.com/docs/grafana/latest/administration/service-accounts/#service-account-tokens) with enough permissions - e.g. admin*)

### Step by step

1. **Create a `main.tf` file** with a main definition:

    ```terraform
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
    ```

2. **Create a `vars.tf` file** with the variables' definition (*will be read from environment*):

    ```terraform
    variable "GRAFANA_URL" {
      type        = string
      description = "Fully qualified domain name of your Grafana instance."
    }

    variable "GRAFANA_TOKEN" {
      type        = string
      description = "Basic auth password or API token."
    }
    ```

3. **Initialize** a new Terraform working directory:

    ```sh
    terraform init
    ```

4. **Create a `resources.tf` file** with a basic dashboard and the resource definition:

    ```terraform
    data "schemas_core_dashboard" "example" {
      title = "Terraform example"
      description = "Example dashboard built with Terraform"
    }

    resource "grafana_dashboard" "example" {
      config_json = data.schemas_core_dashboard.example.rendered_json
    }
    ```

## Contribute

Have you detected a typo or something incorrect, and you are **willing to contribute?**

Please, [open a pull request](https://github.com/joanlopez/terraform-grafana-example/compare), and I'll be happy to review it.