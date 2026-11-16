<!--
Requesting a VM? This PR must contain exactly ONE new file under requests/<env>/
and nothing else. Copy requests/_template.tfvars.json. Changes to modules,
stacks or workflows need their own PR.
-->

## Why is this VM needed?
<!-- Business justification. The approver reads this together with the plan comment. -->

## Details
- **Request ID:**
- **VM name:**
- **Needed by / expected lifetime:**
- **Project / cost centre:**

## Checklist
- [ ] One request file only, named `<vm_name>.tfvars.json`, in the folder matching its environment
- [ ] `requester` in the file is my GitHub username
- [ ] The `justification` field in the file is filled in
- [ ] I have looked at the plan comment posted by the pipeline

_Nothing is created until a manager approves and merges this PR and the deployment is approved._
