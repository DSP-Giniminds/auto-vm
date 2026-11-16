#!/usr/bin/env python3
"""Work out what a change contains and enforce "one request per change".

Also checks the request file itself (required fields, file name, folder, unique ID).

Sets the step output `scope`:
  request  exactly one request file changed, nothing else
  infra    no request file changed (modules, stacks, workflows, docs ...)
  none     nothing changed
and, for a request, `request_file` and `request_id`.

The change is rejected if it touches more than one request file, mixes a request
with any other file, deletes a request, or adds a bad path under requests/.

Usage:
  detect_request.py --base <sha> --head <sha>     compare two commits
  detect_request.py --request-file <path>         workflow_dispatch: the caller names the file
"""
import argparse
import glob
import subprocess

from common import FRAMEWORK_FILES, REQUEST_PATH_RE, fail, load_json, set_output

REQUIRED_FIELDS = [
    "request_id", "target", "vm_name", "requester", "environment", "instance_type",
    "os", "root_volume_gb", "subnet_id", "security_group_ids", "justification",
]
SUPPORTED_TARGETS = {"aws-ec2"}  # add "vmware" etc. when another stack exists


def changed_files(base, head):
    """Return [(status, path)]. Renames are reported as a delete plus an add."""
    if set(base) <= {"0"}:  # first push of a branch: compare with the parent
        base = f"{head}^"
    result = subprocess.run(
        ["git", "diff", "--name-status", "--no-renames", f"{base}...{head}"],
        check=True, capture_output=True, text=True,
    )
    return [tuple(line.split("\t", 1)) for line in result.stdout.splitlines()]


def check_request(path):
    """Return the problems in one request file. Terraform cannot see these (file name, folder, other files).

    Field values (types, allowlists, name format) are validated by the Terraform module.
    """
    folder, file_name = REQUEST_PATH_RE.match(path).groups()
    try:
        request = load_json(path)
    except ValueError as error:
        return [f"{path} is not valid JSON: {error}"]

    errors = [f"{path}: missing field \"{f}\"." for f in REQUIRED_FIELDS if f not in request]
    if request.get("vm_name") != file_name:
        errors.append(f"{path}: vm_name must equal the file name \"{file_name}\".")
    if request.get("environment") != folder:
        errors.append(f"{path}: environment must equal the folder name \"{folder}\".")
    if request.get("target") not in SUPPORTED_TARGETS:
        errors.append(f"{path}: target must be one of {sorted(SUPPORTED_TARGETS)}.")
    for other in glob.glob("requests/*/*.tfvars.json"):
        if other != path and not other.split("/")[-1].startswith("_"):
            if load_json(other).get("request_id") == request.get("request_id"):
                errors.append(f"{path}: request_id is already used by {other}.")
    return errors


def report_request(path):
    errors = check_request(path)
    if errors:
        fail(errors)
    set_output("scope", "request")
    set_output("request_file", path)
    set_output("request_id", load_json(path)["request_id"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="")
    parser.add_argument("--head")
    parser.add_argument("--request-file")
    args = parser.parse_args()

    if args.request_file:  # dispatch: any front door (e.g. ServiceNow) names the file
        if not REQUEST_PATH_RE.match(args.request_file):
            fail([f"{args.request_file} is not a request path (requests/<env>/<vm_name>.tfvars.json)."])
        report_request(args.request_file)
        return

    requests, others, errors = [], [], []
    for status, path in changed_files(args.base, args.head):
        if REQUEST_PATH_RE.match(path):
            requests.append((status, path))
        elif path.startswith("requests/") and path not in FRAMEWORK_FILES:
            errors.append(f"{path} is not a request path (requests/<env>/<vm_name>.tfvars.json).")
        else:
            others.append(path)

    if not requests:
        if errors:
            fail(errors)
        set_output("scope", "infra" if others else "none")
        return

    if len(requests) > 1:
        errors.append("Only one request file per change. Found: " + ", ".join(p for _, p in requests))
    if others:
        errors.append("A request must not be mixed with other changes. Also changed: " + ", ".join(others))
    errors += [f"{p}: deleting a request is not supported." for s, p in requests if s == "D"]
    if errors:
        fail(errors)

    report_request(requests[0][1])


if __name__ == "__main__":
    main()
