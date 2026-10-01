"""Wait for this exact commit's iPhone and iPad test jobs before packaging.

Read-only Actions API access uses the current workflow's scoped GitHub token.
"""
import json
import os
import time
import urllib.request


def fetch(path):
    request = urllib.request.Request("https://api.github.com/repos/x6one/hashiya-ios/" + path,
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"],
                 "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def require():
    sha = os.environ["GITHUB_SHA"]
    for _ in range(60):
        runs = fetch("actions/runs?head_sha=" + sha + "&event=push&per_page=30")["workflow_runs"]
        matching = [r for r in runs if r["head_sha"] == sha and r["name"] == "iPhone and iPad preflight"]
        if matching:
            run = max(matching, key=lambda r: r["id"])
            jobs = fetch(f"actions/runs/{run['id']}/jobs?per_page=100")["jobs"]
            tests = [j for j in jobs if j["name"] in {"test (iPhone)", "test (iPad)"}]
            if any(j["status"] == "completed" and j["conclusion"] != "success" for j in tests):
                raise RuntimeError("Simulator verification failed; do not package a native IPA")
            if len(tests) == 2 and all(j["conclusion"] == "success" for j in tests):
                print(f"Both simulator suites passed for {sha}; preflight run {run['id']}")
                return
        time.sleep(15)
    raise RuntimeError("Simulator verification is still incomplete; no IPA was packaged")


if __name__ == "__main__":
    require()
