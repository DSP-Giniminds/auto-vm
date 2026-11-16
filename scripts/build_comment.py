#!/usr/bin/env python3
"""Write the Markdown for a pipeline comment on the PR to stdout.

  build_comment.py plan    --request-file F --plan-file P
  build_comment.py problem --title T --text-file F
  build_comment.py result  --request-file F --status S --result-dir D [--pr N]

GitHub limits a comment to 65,536 characters, so long text is cut and the full
text stays in the workflow run.
"""
import argparse
import json
import os
import subprocess

from common import load_json

REPO = os.environ.get("GITHUB_REPOSITORY", "")
RUN_URL = f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{REPO}/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}"


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def gh_api(path):
    out = subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def spec_table(request):
    rows = {
        "Request ID": request["request_id"],
        "VM name": request["vm_name"],
        "Requester": request["requester"],
        "Environment": request["environment"],
        "Instance type": request["instance_type"],
        "OS": request["os"],
        "Root volume": f"{request['root_volume_gb']} GB gp3, encrypted",
        "Subnet": request["subnet_id"],
        "Security groups": ", ".join(request["security_group_ids"]),
        "Public IP": "yes" if request.get("assign_public_ip") else "no",
    }
    return "\n".join(["| Field | Value |", "|---|---|"] + [f"| {k} | `{v}` |" for k, v in rows.items()])


def plan(args):
    request = load_json(args.request_file)
    text = read(args.plan_file)
    if len(text) > 55_000:
        text = text[:55_000] + f"\n... (cut, full plan in the workflow run)"
    print(f"## VM request plan\n\n{spec_table(request)}\n")
    print(f"**Justification:** {request['justification']}\n")
    print("### What Terraform will create once this is approved and merged\n")
    print(f"```\n{text}\n```\n")
    print(f"_Plan run: {RUN_URL}. Nothing is created until the PR is approved and merged "
          "and the deployment is approved._")


def problem(args):
    text = read(args.text_file)[-6_000:]
    print(f"## {args.title}\n\n{text}\n\n_Run: {RUN_URL}_")


def audit_lines(pr_number):
    """Who approved and when. Best effort: a failed lookup must not hide the result."""
    lines = []
    try:
        if pr_number:
            pr = gh_api(f"repos/{REPO}/pulls/{pr_number}")
            lines.append(f"- PR #{pr_number} opened by `{pr['user']['login']}`")
            if pr.get("merged_at"):
                lines.append(f"- Merged by `{pr['merged_by']['login']}` at {pr['merged_at']}")
            for review in gh_api(f"repos/{REPO}/pulls/{pr_number}/reviews"):
                if review["state"] == "APPROVED":
                    lines.append(f"- PR approved by `{review['user']['login']}` at {review['submitted_at']}")
        for a in gh_api(f"repos/{REPO}/actions/runs/{os.environ['GITHUB_RUN_ID']}/approvals"):
            env = ", ".join(e["name"] for e in a["environments"])
            lines.append(f"- Deployment to `{env}` {a['state']} by `{a['user']['login']}`")
    except Exception as error:  # noqa: BLE001
        lines.append(f"- (approval details unavailable: {error})")
    return lines


def result(args):
    request = load_json(args.request_file)
    status = args.status if args.status in ("success", "cancelled") else "failure"
    icon = {"success": "✅", "cancelled": "⚪", "failure": "❌"}[status]
    print(f"## {icon} VM provisioning: {status}\n")
    print(f"**Request:** `{request['request_id']}`  **VM:** `{request['vm_name']}`\n")

    if status == "success":
        outputs = json.loads(read(os.path.join(args.result_dir, "outputs.json")) or "{}")
        print("| Result | Value |\n|---|---|")
        for label, key in [("Instance ID", "instance_id"), ("Private IP", "private_ip"),
                           ("Public IP", "public_ip"), ("AMI", "ami_id")]:
            if outputs.get(key, {}).get("value"):
                print(f"| {label} | `{outputs[key]['value']}` |")
        print()
    else:
        # The apply log explains an apply failure; otherwise the plan failed.
        log = read(os.path.join(args.result_dir, "apply.log")) or read(os.path.join(args.result_dir, "plan.log"))
        print(f"### Reason\n\n```\n{log[-6_000:] or 'No log captured. See the workflow run.'}\n```\n")

    print(f"**Execution log:** {RUN_URL}\n\n### Audit\n")
    print("\n".join(audit_lines(args.pr)))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="kind", required=True)

    p = sub.add_parser("plan")
    p.add_argument("--request-file", required=True)
    p.add_argument("--plan-file", required=True)
    p.set_defaults(run=plan)

    p = sub.add_parser("problem")
    p.add_argument("--title", required=True)
    p.add_argument("--text-file", required=True)
    p.set_defaults(run=problem)

    p = sub.add_parser("result")
    p.add_argument("--request-file", required=True)
    p.add_argument("--status", required=True)
    p.add_argument("--result-dir", required=True)
    p.add_argument("--pr", default="")
    p.set_defaults(run=result)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
