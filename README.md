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

5. **Set up Grafana and Terraform auth** as [Actions secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets):

   - `GRAFANA_URL` with the root url of your instance
   - `GRAFANA_TOKEN` with your service account token
   - `TF_API_TOKEN` with your Terraform Cloud API token

   Additionally, you may want to set up the following variables:

   - `TF_CLOUD_ORGANIZATION` with the id of your Terraform cloud organization
   - `TF_WORKSPACE` with the id of your Terraform cloud workspace

6. **Set up GitHub Actions** to automatically `terraform plan` your changes on every pull request:

    ```yaml
    # .github/workflows/terraform-plan.yml

    name: "Terraform Plan"

    on:
      pull_request:

    env:
      TF_CLOUD_ORGANIZATION: "${{ vars.TF_CLOUD_ORGANIZATION }}"
      TF_API_TOKEN: "${{ secrets.TF_API_TOKEN }}"
      TF_WORKSPACE: "${{ vars.TF_WORKSPACE }}"
      CONFIG_DIRECTORY: "./"

    jobs:
      terraform:
        name: "Terraform Plan"
        runs-on: ubuntu-latest
        permissions:
          contents: read
          pull-requests: write
        steps:
          - name: Checkout
            uses: actions/checkout@v3

          - name: Upload Configuration
            uses: hashicorp/tfc-workflows-github/actions/upload-configuration@v1.0.0
            id: plan-upload
            with:
              workspace: ${{ env.TF_WORKSPACE }}
              directory: ${{ env.CONFIG_DIRECTORY }}
              speculative: true

          - name: Create Plan Run
            uses: hashicorp/tfc-workflows-github/actions/create-run@v1.0.0
            id: plan-run
            with:
              workspace: ${{ env.TF_WORKSPACE }}
              configuration_version: ${{ steps.plan-upload.outputs.configuration_version_id }}
              plan_only: true

          - name: Get Plan Output
            uses: hashicorp/tfc-workflows-github/actions/plan-output@v1.0.0
            id: plan-output
            with:
              plan: ${{ fromJSON(steps.plan-run.outputs.payload).data.relationships.plan.data.id }}

          - name: Update PR
            uses: actions/github-script@v6
            id: plan-comment
            with:
              github-token: ${{ secrets.GITHUB_TOKEN }}
              script: |
                // 1. Retrieve existing bot comments for the PR
                const { data: comments } = await github.rest.issues.listComments({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  issue_number: context.issue.number,
                });
                const botComment = comments.find(comment => {
                  return comment.user.type === 'Bot' && comment.body.includes('Terraform Cloud Plan Output')
                });
                const output = `#### Terraform Cloud Plan Output
                   \`\`\`
                   Plan: ${{ steps.plan-output.outputs.add }} to add, ${{ steps.plan-output.outputs.change }} to change, ${{ steps.plan-output.outputs.destroy }} to destroy.
                   \`\`\`
                   [Terraform Cloud Plan](${{ steps.plan-run.outputs.run_link }})
                   `;
                // 3. Delete previous comment so PR timeline makes sense
                if (botComment) {
                  github.rest.issues.deleteComment({
                    owner: context.repo.owner,
                    repo: context.repo.repo,
                    comment_id: botComment.id,
                  });
                }
                github.rest.issues.createComment({
                  issue_number: context.issue.number,
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  body: output
                });
    ```

7. **Set up GitHub Actions** to automatically `terraform apply` your changes on every push to `main`:

    ```yaml
    # .github/workflows/terraform-apply.yml

    name: "Terraform Apply"

    on:
      push:
        branches:
          - main

    env:
      TF_CLOUD_ORGANIZATION: "${{ vars.TF_CLOUD_ORGANIZATION }}"
      TF_API_TOKEN: "${{ secrets.TF_API_TOKEN }}"
      TF_WORKSPACE: "${{ vars.TF_WORKSPACE }}"
      CONFIG_DIRECTORY: "./"

    jobs:
      terraform:
        name: "Terraform Apply"
        runs-on: ubuntu-latest
        permissions:
          contents: read
        steps:
          - name: Checkout
            uses: actions/checkout@v3

          - name: Upload Configuration
            uses: hashicorp/tfc-workflows-github/actions/upload-configuration@v1.0.0
            id: apply-upload
            with:
              workspace: ${{ env.TF_WORKSPACE }}
              directory: ${{ env.CONFIG_DIRECTORY }}

          - name: Create Apply Run
            uses: hashicorp/tfc-workflows-github/actions/create-run@v1.0.0
            id: apply-run
            with:
              workspace: ${{ env.TF_WORKSPACE }}
              configuration_version: ${{ steps.apply-upload.outputs.configuration_version_id }}

          - name: Apply
            uses: hashicorp/tfc-workflows-github/actions/apply-run@v1.0.0
            if: fromJSON(steps.apply-run.outputs.payload).data.attributes.actions.IsConfirmable
            id: apply
            with:
              run: ${{ steps.apply-run.outputs.run_id }}
              comment: "Apply Run from GitHub Actions CI ${{ github.sha }}"
    ```

## Contribute

Have you detected a typo or something incorrect, and you are **willing to contribute?**

Please, [open a pull request](https://github.com/joanlopez/terraform-grafana-example/compare), and I'll be happy to review it.