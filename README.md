# auto-vm: governed VM requests with Terraform and GitHub Actions

## What this is

A small self-service pipeline for getting an AWS EC2 virtual machine. You ask for a VM
by opening a pull request. A reviewer approves it, and a pipeline builds it. Nothing is
created without approval, and every request leaves a record in Git.

It uses Terraform, GitHub Actions, and AWS OIDC, so no AWS keys are stored anywhere.

## What it does

- Takes a VM request as one small JSON file.
- Checks the request and scans the code for security problems.
- Shows the reviewer exactly what would be created, as a plan on the PR.
- Builds the VM only after two approvals.
- Reports the result (instance ID, IP) back on the PR.
- Can destroy and recreate a VM from the same request file.

## How it works

```
Open PR with a request file
        |
  request-plan: validate + security scan + plan  --> plan posted on the PR
        |
  Reviewer approves and merges            (approval 1: code owner)
        |
  request-apply: plan again, then waits   (approval 2: aws-apply environment)
        |
  VM is created, result commented on the PR
```

## How to request a VM

1. Branch from `main`.
2. Copy `requests/_template.tfvars.json` to `requests/<env>/<vm_name>.tfvars.json`.
3. Fill it in. The file name must equal `vm_name`, and the folder must equal `environment`.
   Use a new `request_id`.
4. Commit only that one file, push, and open a PR into `main`.
5. Read the plan comment the pipeline posts. Fix anything it reports and push again.
6. Wait for approval and merge, then for the deployment approval.

Rules enforced automatically: one request file per PR (nothing else in the same PR),
all required fields present, unique `request_id`, allowed instance types only
(`t3.micro`, `t2.micro`).

## The workflows

**request-plan** runs on every pull request. It never creates anything.
- `validate`: checks the request file, `terraform fmt`, and `terraform validate`.
- `security`: runs tflint, Checkov, and gitleaks (in parallel with validate).
- `plan`: only if the PR holds a request file. Runs `terraform plan` with a read-only
  role and posts it as a comment.

**request-apply** runs when a request is merged into `main`, or by hand.
- `prepare`: re-validates the merged request.
- `plan`: makes a fresh plan and saves it.
- `apply`: waits for approval in the `aws-apply` environment, then applies the exact
  saved plan with the write role.
- `report`: always runs. Comments success or failure on the PR.

**demo-cleanup** is manual and runs on `main` only. After approval and typing the
`request_id`, it destroys one request's VM. The request file stays in Git, so running
`request-apply` again recreates the VM.

A PR with no request file (code, docs, workflows) runs `validate` and `security` only.

## How to operate

**Create a VM again:** Actions, `request-apply`, Run workflow on `main`, enter the
request file path, then approve at `aws-apply`.

**Destroy a VM:** Actions, `demo-cleanup`, enter the request file path and its
`request_id`, then approve at `aws-apply`.

**Change an existing VM:** open a new request PR with the changed values.

**First-time setup (once):**
1. In `bootstrap/`, copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored)
   and fill it in. Run `terraform apply` with your own AWS credentials.
2. Set `github_repo` to the exact subject prefix GitHub shows under Repo, Settings,
   Actions, General, "Default subject claim prefix", **without** the leading `repo:`.
   Newer repos use IDs, for example `DSP-Giniminds@<owner-id>/auto-vm@<repo-id>`.
   A wrong value gives "Not authorized to perform sts:AssumeRoleWithWebIdentity".
3. Set the repository variables: `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`,
   `AWS_REGION`, `STATE_BUCKET`.
4. Create the `aws-apply` environment with required reviewers.
5. Add a ruleset on `main`: pull request required, 1 approval, code-owner review, and
   required checks `validate`, `security` and `plan`.

## CI/CD flow in short

- **CI (on the pull request):** validate the request, format and syntax checks,
  security scans, and a plan. Nothing touches AWS except a read-only plan.
- **Approval:** a code owner reviews the plan and merges.
- **CD (after merge):** a fresh plan is saved, a second approval is required, and the
  exact saved plan is applied. The result is reported back on the PR.

## DevSecOps: what security is built in

**Shift left (checked before merge):**
- tflint: finds incorrect or risky Terraform.
- Checkov: finds insecure configuration (open ports, missing encryption, wide IAM).
  Accepted risks are skipped inline, each with a written reason.
- gitleaks: finds secrets committed in the PR.
- Request rules block malformed, duplicate, or mixed requests.

**Access control:**
- No stored AWS keys. GitHub OIDC gives short-lived credentials.
- A read-only plan role for PR checks, and a separate write role usable only from the
  protected `aws-apply` environment.
- The write role can launch only allowed instance types, only with the required tag,
  and can manage only resources the pipeline created.
- CODEOWNERS separates who approves requests from who changes the pipeline itself.

**Approval gates:**
- Gate 1: code-owner approval and passing checks before merge.
- Gate 2: environment approval before anything is applied.

**Safe VM defaults:** IMDSv2 only, encrypted root volume, no public IP unless asked,
no instance profile.

**Protected state and audit trail:**
- Terraform state in a private, encrypted, versioned S3 bucket, one state per request.
- Every VM is tagged with its request ID, requester, PR and commit.
- Approvals, plans, logs, and the result comment are kept in GitHub and CloudTrail.

## Repository layout

- `bootstrap/`: one-time setup (state bucket, OIDC, plan and apply roles).
- `modules/aws-ec2-vm/`: the VM definition.
- `stacks/aws-ec2-vm/`: connects a request to the module, one state per request.
- `requests/`: one JSON file per VM request, plus the template.
- `.github/workflows/`: `request-plan`, `request-apply`, `demo-cleanup`.
- `.github/actions/terraform-init/`: shared init step.
- `.github/CODEOWNERS`: who approves what.
- `scripts/`: request checks and PR comment helpers.
- `.tflint.hcl`: tflint configuration.
