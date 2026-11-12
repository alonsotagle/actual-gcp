# actual-gcp
Actual Budget hosted on Google Cloud's always free tier

## Background
The goal of this repository is to deploy [Actual Budget][1] running on [Google Cloud's][2] [Free Tier][3], using the Compute Engine service. This setup utilizes [Terraform][4] to deploy and automatically configure the cloud infrastructure. Some manual steps may still need to be taken, but I've tried to remove as many as possible and document the rest.

Some notes about the architecture of this setup:

* The Compute Engine instance is deployed using Google's [Container Optimized OS][5] image and the applications run within this instance using [Docker][6].
* [Tailscale][7] is used for private, encrypted mesh networking and access control.
* [Caddy][8] is used as an internal reverse proxy.
* [Actual MCP Server](https://github.com/sstefanov/actual-mcp) runs alongside Actual Budget to expose an MCP interface over Tailscale.
* Automated daily SQLite backups are created via a systemd timer and uploaded to Google Cloud Storage.
* [Terraform state][9] management is being handled by [HCP Terraform (formerly Terraform Cloud)][10].

**Disclaimer**: While I've attempted to ensure that all cloud infrastructure being deployed is part of GCP's free tier, you are ultimately responsible for your own cloud spend. The Terraform code sets up an adjustible monthly billing alert to help mitigate risk of unexpected cloud costs, but it is your responsibility to monitor your cloud account.

[1]: https://actualbudget.com/
[2]: https://cloud.google.com
[3]: https://cloud.google.com/free/docs/free-cloud-features?_gl=1*16i0xkv*_up*MQ..&gclid=EAIaIQobChMItuHQrcyPiQMVFUL_AR2RuhIpEAAYASAAEgKEkPD_BwE&gclsrc=aw.ds#free-tier-usage-limits
[4]: https://www.terraform.io
[5]: https://cloud.google.com/container-optimized-os/docs
[6]: https://www.docker.com
[7]: https://tailscale.com/
[8]: https://caddyserver.com/
[9]: https://developer.hashicorp.com/terraform/language/state
[10]: https://app.terraform.io
[11]: https://cloud.google.com/sdk/docs/install
[12]: https://developer.hashicorp.com/terraform/install
[13]: https://cloud.google.com/architecture/best-practices-vpc-design#custom-mode
[14]: https://developer.hashicorp.com/terraform/tutorials/cloud-get-started/cloud-login
[15]: https://git-scm.com/downloads/win
[16]: https://cloud.google.com/billing/docs/resources/currency#list_of_countries_and_regions
[17]: https://actualbudget.com/docs/overview/getting-started/

## Pre-requisites
* A [Google Cloud][2] account
* A free [HCP Terraform][10] account (unless you want to host your state locally or elsewhere)
* A [Tailscale][7] account and auth key
* The [Google Cloud CLI][11] tools installed
* [Terraform][12] installed

## Instructions
1. If you haven't already, generate a [Tailscale auth key](https://login.tailscale.com/admin/settings/keys).
2. If you haven't already, create your organization, project (unless you're using the Default project), and workspace in [HCP Terraform][10]. This repository assumes you've created your workspace using the CLI-Driven Workflow, but you can choose one of the other methods if you're comfortable adapting the instructions to accommodate it.
    * ![HCP Terraform New Workspace](./readme_resources/hcp_tf_new_workspace.png)
3. Within your workspace, navigate to Settings > General and scroll down to Execution Mode. Set it to "Local (Custom)". This will ensure that you can execute Terraform commands at the command line. By default, the workspace will be set to your Organization Default, which may already be set to Local. If your Organization Default is Local, you don't necessarily need to force the workspace to Local, but it also won't hurt to do so. Additionally, if you are deviating from these instructions and opting to choose to run Terraform within HCP Terraform and not on your local machine, you can ignore this step and select your desired Execution Mode for your custom setup.
    * ![HCP Terraform Execution Mode](./readme_resources/hcp_tf_execution_mode.png)
4. *Optional* - Run the following command to create an SSH public/private key-pair (if on Windows, you may need to [install Git][15] first):
    * `ssh-keygen`
    * **Note** - This will be used for SSH key-pair authentication when connecting directly, without the use of the Google SSH proxy. This configuration disables direct SSH access by default, though a firewall rule does get created to allow it. It is included in case short-term "break glass" / emergency access is needed.
5. Clone this repository to your machine (or create a fork and clone your fork) and open a terminal session into the repository's directory.
6. Run the following command to initialize your Google Cloud command line tools: 
    * `gcloud init`
7. Run the following command to make your user credentials available to Application Default Credentials (ADC):
    * `gcloud auth application-default login`
8. Run the following command to enable the API services necessary for Terraform to run and configure the rest of the environment:
    * `gcloud services enable cloudresourcemanager.googleapis.com`
9. If this is a new Google Cloud environment, I recommend running the following commands to delete the default networking configuration, as new configurations will be deployed via Terraform:
    * `gcloud compute firewall-rules list`
    * For each firewall rule listed, run `gcloud compute firewall-rules delete rulename`
    * `gcloud compute networks delete default`
    * If you already have resources active using the default VPC, skip this step and update the Terraform code to remove the new 'google_compute_network' and 'google_compute_route' resources, as well as modifying the network for the 'google_compute_firewall' and 'google_compute_instance' resources.
    * Deleting the default network and using a custom network helps align with [documented best-practices regarding VPC design][13].
10. We're now ready to begin configuring our local Terraform environment. Run the following command to [authenticate with HCP Terraform][14]:
    * `terraform login`
11. Make the following updates to the following files in the repository:
    * Update `backend.tf` with your organization and workspace names from HCP Terraform.
    * Create a file named `sensitive.auto.tfvars` and set the following variables:
        * `ts_authkey` - Your Tailscale auth key.
        * `actual_password` - Password for Actual Budget.
        * `actual_budget_sync_id` - Budget Sync ID for Actual Budget.
        * `mcp_bearer_token` - Bearer Token for the Actual MCP server.
        * `gcp_billing_project_name` - The name of your GCP billing project.
        * `gcp_project_name` - The name of your GCP project.
        * `gcp_region` - The GCP region you wish your workload to run in (for example, "us-central1").
        * `gcp_zone` - The zone within the GCP region you want to use (for example, "us-central1-a").
        * `user` - Your Google username (without the "@gmail.com") for console SSH.
        * `billing_account_name` - (Optional) Defaults to "My Billing Account".
        * `billing_alert_amount` - (Optional) Defaults to "5".
        * **Note** - The `.gitignore` file is configured to ignore any *.auto.tfvars files. Be extremely cautious with what variable values you allow to be pushed to your source control (Git) repository.
        * **Note** - You could also define these variables within HCP Terraform if you want to have your Terraform actions performed there instead of your local command line.
        * ![Example Variables](./readme_resources/variable_values.png)
12. Run the following command to initiate Terraform:
    *  `terraform init`
13. Run the following command to execute a "plan" operation, where we can inspect what Terraform operations are expected to happen when the "apply" operation happens:
    *  `terraform plan`
14. Once you've reviewed the output of the "plan" operation and are ready to deploy the infrastructure, run the following command and confirm when prompted:
    * `terraform apply`
15. *Optional* - Post-deployment validation:
    * Once the "apply" operation has completed, navigate to the Google Cloud web console and inspect the new virtual machine.
        * ![Provisioned VM](./readme_resources/gcp_post_deployment.png)
    * **Note** - You can also run the following Google Cloud command to validate the new virtual machine:
        * `gcloud compute instances list`
        * `gcloud compute instances describe containerhost01`
    * Connect via Google Cloud Console SSH (IAP). Once connected, run `docker ps -a`. You should see containers running for:
        * `actual_server`
        * `actual_mcp`
        * `caddy`
        * `tailscale`
    * You can inspect their associated systemctl services:
        * `systemctl status actual`
        * `systemctl status actual-mcp`
        * `systemctl status caddy`
        * `systemctl status tailscale`
        * `systemctl status actual-backup.timer`
    * If the containers are running, but things aren't working as-expected, use the following commands to inspect the container logs to further troubleshoot:
        * `docker logs actual_server`
        * `docker logs actual_mcp`
        * `docker logs caddy`
        * `docker logs tailscale`
    * Run the following command to ensure the applications' "data" directory has been mounted onto the Persistent Disk (/dev/sdb):
        * ![lsblk output](./readme_resources/lsblk_output.png)
        * **Important** This part of the configuration is critical to application data persisting across virtual machine reboots.
16. Open your web browser and navigate to your Tailscale MagicDNS hostname (e.g. `https://actual.<tailnet>.ts.net`). You should see the Actual Budget login page. Follow [Actual Budget's Getting Started][17] page for next steps.
    * ![Actual Budget login](./readme_resources/actual_login_page.png)

## Updating Actual Server
There are a couple of ways you could use to try to update Actual Server to a newer version.

1. Re-run `terraform apply`. If a newer version of the Google Container Optimized OS image has been published, the virtual machine will be destroyed and re-deployed, pulling the latest version of the actualbudget/actual-server container during the re-deploy.
2. If you want to manually trigger an update, you can perform the following steps:
    * SSH into the virtual machine.
        * ![GCP Console SSH](./readme_resources/ssh_vm.png)
    * Issue the following commands:
        ```
        docker pull actualbudget/actual-server:latest
        sudo systemctl restart actual
        ```
        * ![Manual update container](./readme_resources/update_container.png)
    * Your server should now reflect the most recent version.
        * ![Version check](./readme_resources/actual_update.png)
