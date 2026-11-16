# Governed VM provisioning (Git-native, phase 1)

A pull request asks for a VM, a manager approves it, and a pipeline builds it.
Nothing is created without approval, and every step leaves a record. It uses the
free Terraform CLI, GitHub Actions on GitHub-hosted runners, AWS OIDC (no stored
AWS keys) and an S3 state bucket with native locking (no DynamoDB).

## How a request flows

```
 requester                    GitHub                         AWS
 ─────────                    ──────                         ───
 PR adds ONE file  ──►  request-plan.yml
 requests/dev/vm.json     validate (schema, naming, one-file rule)
                          terraform fmt / validate
                          plan (read-only role) ──► plan posted on the PR
                                │
 manager reviews plan ◄─────────┘
 manager approves + merges  (CODEOWNERS + branch protection = gate 1)
                                │
                          request-apply.yml (push to main)
                            plan   (read-only role, saved plan file)
                            apply  environment "aws-apply" waits for a
                                   reviewer (gate 2) ──► apply role ──► EC2 instance
                            report  result or failure ──► comment on the merged PR
```

A rejected or closed PR never reaches `main`, so nothing runs.

## Repository layout

| Path | Purpose |
|---|---|
| `bootstrap/` | One-time, applied locally: state bucket, GitHub OIDC provider, plan and apply roles (`s3.tf`, `oidc.tf`, `plan_role.tf`, `apply_role.tf`) |
| `modules/aws-ec2-vm/` | Reusable EC2 module: validation, tags, encrypted gp3 root volume, IMDSv2, offline tests |
| `stacks/aws-ec2-vm/` | Root config. Backend is supplied at init, with one state key per request |
| `requests/<env>/<vm>.tfvars.json` | One file per VM request. `_template.tfvars.json` lives here too |
| `.github/workflows/` | `request-plan`, `request-apply`, `demo-cleanup` |
| `.github/actions/terraform-init/` | Shared init step (per-request state key) |
| `scripts/` | `detect_request.py` (one-request rule and request checks), `build_comment.py`, `post_comment.sh` |
| `docs/` | `DEMO_RUNBOOK.md`, `GITHUB_SETUP.md` |

**Design rule: the pipeline does not care about the front door.**
`request-apply.yml` can also be started with `workflow_dispatch`, giving it a request
file path (and optionally a PR number). A ServiceNow integration can later either open
the same request PR through the API, or commit the file and dispatch the workflow,
with the ticket number as `request_id`.

## Adding an on-prem target later
Add `modules/vmware-vm/` and `stacks/vmware-vm/`, add `vmware` to `target` in
`detect_request.py` (`SUPPORTED_TARGETS`), and have the workflows pick the stack from the request's
`target` field. The request, approval, audit and feedback flow does not change.

## Request rules (enforced by CI)
- One request file per PR, and nothing else in that PR (no modules, stacks or workflows).
- Deleting a request file is rejected (decommissioning is out of scope).
- File name equals `vm_name`; the folder equals `environment`; `request_id` is unique.
- All required fields present (CI). The module rejects a `justification` shorter than 10 characters.
- The module enforces the instance-type allowlist, OS options, name format and sizes again.
  The apply role's IAM policy enforces the instance-type allowlist a third time.

## Tags on every VM
`Name`, `RequestID`, `Requester`, `Environment`, `ManagedBy=terraform-request-pipeline`,
`SourceRepo`, `SourcePR`, `SourceCommit` (the commit it was applied from).

## Audit trail

| Question | Where the answer is |
|---|---|
| Who requested? | PR author and the `requester` field in the request file |
| Why? | `justification` field and the PR description |
| Who approved, and when? | PR review approval; the environment deployment approval on the workflow run. Both are repeated in the result comment |
| What was created, and when? | Apply log in the workflow run, instance tags, result comment (instance ID, IP), CloudTrail entries from role session `gha-apply-<request_id>-<run_id>` |
| What exactly was built? | The request file in Git history plus the saved plan that was applied |
| Rejected requests | The closed, unmerged PR with the reviewer's decision. No workflow ran against AWS |

## Success criteria mapping

| Criterion | How it is met |
|---|---|
| Request raised via a standard form with all fields and justification | PR template + `_template.tfvars.json`; CI rejects a request with a missing field. The request gets a `request_id` |
| No VM without approval; rejected = nothing created | Apply runs only on merge to `main`; merge needs code-owner approval, then the `aws-apply` environment approval. Closed PRs run nothing |
| Approval recorded with identity and timestamp | PR review and deployment approval records, quoted in the result comment |
| Provisioning starts automatically on approval | `request-apply.yml` triggers on merge. The only human action after that is the deployment approval itself |
| VM matches the approved spec | Same file feeds plan and apply; apply uses the saved plan. CPU/RAM follow the instance type, disk is 20 GB gp3, OS is Amazon Linux 2023 |
| VM traceable to request | `RequestID` tag, state key `aws-ec2-vm/<request_id>/`, result comment on the PR |
| Result reported back | Result comment: status, instance ID, private IP, run link |
| Reusable, version-controlled code | `modules/`, `stacks/`, `requests/` in Git with PR history |
| Repeatable | Same request file gives the same VM (AMI is fixed at creation). A different request reuses the same module. `demo-cleanup` then re-running `request-apply` recreates it |
| Failures visible | `report` job comments the failure reason on the PR and turns the run red |
| Cloud and on-prem design | One target demonstrated; see "Adding an on-prem target later" |

## Getting started
1. Apply `bootstrap/` (see `bootstrap/terraform.tfvars.example`; run with your own AWS credentials, review the plan first).
2. Configure GitHub as described in `docs/GITHUB_SETUP.md`.
3. Replace the placeholders: `.github/CODEOWNERS`, `requester` and the network IDs in
   `requests/dev/demo-app-01.tfvars.json` (the committed IDs are format-valid dummies).
4. Follow `docs/DEMO_RUNBOOK.md`.

## Local checks (no AWS credentials needed)
```
terraform fmt -check -recursive
for d in bootstrap modules/aws-ec2-vm stacks/aws-ec2-vm; do
  terraform -chdir=$d init -backend=false && terraform -chdir=$d validate
done
python3 scripts/detect_request.py --request-file requests/dev/demo-app-01.tfvars.json
```

## Known limits of this phase
- Plans on PRs run repository code with the read-only plan role. Fork PRs are not supported.
- Two requests applying at once are protected by the S3 lock: the second fails and can be re-run.
- `ignore_changes = [ami]`: a new AWS image never silently replaces an existing VM.
- The IAM policies are tight and were written without a live account. Expect to widen one
  permission if the first real apply reports `AccessDenied`; the error names the action.
- GitHub Actions in the workflows are pinned to major versions; pin to commit SHAs for production.
