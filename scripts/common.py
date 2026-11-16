"""Small helpers shared by the pipeline scripts."""
import json
import os
import re
import sys

# requests/<environment>/<vm_name>.tfvars.json (names starting with "_" are templates).
REQUEST_PATH_RE = re.compile(r"^requests/([a-z0-9-]+)/([a-z0-9][a-z0-9-]*)\.tfvars\.json$")

# Files under requests/ that belong to the framework, not to a VM request.
FRAMEWORK_FILES = {"requests/_template.tfvars.json"}


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def fail(errors):
    """Print every problem as a bullet on stderr (the workflow copies it to the PR) and exit 1."""
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)


def set_output(name, value):
    """Set a GitHub Actions step output. Outside Actions, just print it."""
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as f:
            f.write(f"{name}={value}\n")
    else:
        print(f"{name}={value}")
