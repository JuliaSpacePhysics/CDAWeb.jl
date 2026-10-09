#!/usr/bin/env python3
"""Run each task of tasks.toml as a headless Claude Code agent, per arm and model; report cost and correctness."""

import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import statistics
import subprocess
import tempfile
import time
import tomllib
from pathlib import Path

EVAL = Path(__file__).resolve().parent

ARMS = {
    # The README preloaded, as a skill or CLAUDE.md would put it: no turn spent reading it
    "cdaweb": f"Use Julia with CDAWeb.jl: `julia --project={EVAL}` has it, with Dates, Statistics and LinearAlgebra. Its README:\n\n{(EVAL.parent / 'README.md').read_text()}",
    "baseline": "Use any tools or libraries except CDAWeb.jl; install what you need.",
}
SYSTEM = "End your reply with a line `ANSWER: <number>`."


def run(task, arm, model, rep, outdir):
    work = Path(tempfile.mkdtemp(prefix=f"cdaweb-eval-{task['id']}-{arm}-"))
    cmd = ["claude", "-p", f"{ARMS[arm]}\n\n{task['prompt']}", "--model", model,
           "--output-format", "stream-json", "--verbose", "--permission-mode", "bypassPermissions",
           "--no-session-persistence", "--append-system-prompt", SYSTEM,
           # The runner's own CLAUDE.md, hooks and skills would make results depend on whose machine runs them
           "--setting-sources", "project", "--disable-slash-commands"]
    # Persistent so pyspedas reruns hit its cache, as CDAWeb.jl's ~/.cdaweb does
    env = os.environ | {"SPEDAS_DATA_DIR": str(Path.home() / ".cache" / "cdaweb-eval" / "pydata")}
    t0 = time.time()
    proc = subprocess.run(cmd, cwd=work, env=env, capture_output=True, text=True)
    log = outdir / f"{task['id']}.{arm}.{model}.{rep}.jsonl"
    log.write_text(proc.stdout)
    final = next((json.loads(l) for l in reversed(proc.stdout.splitlines()) if '"type":"result"' in l), {})
    u = final.get("usage", {})
    m = re.findall(r"ANSWER:\s*\**\s*([-+]?[0-9][0-9,]*\.?[0-9]*(?:[eE][-+]?[0-9]+)?)", final.get("result", ""))
    answer = float(m[-1].replace(",", "")) if m else None
    tol = max(task.get("atol", 0.0), task.get("rtol", 0.0) * abs(task["answer"]))
    shutil.rmtree(work, ignore_errors=True)
    return {
        "task": task["id"], "arm": arm, "model": model, "answer": answer, "truth": task["answer"],
        "correct": answer is not None and abs(answer - task["answer"]) <= tol,
        "turns": final.get("num_turns"), "cost": final.get("total_cost_usd"),
        "context_tokens": sum(u.get(k, 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")),
        "output_tokens": u.get("output_tokens"), "seconds": round(time.time() - t0), "log": log.name,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tasks", nargs="*", help="task ids (default: all)")
    p.add_argument("--arms", nargs="*", default=list(ARMS), choices=list(ARMS))
    p.add_argument("--models", nargs="*", default=["sonnet"])
    p.add_argument("-n", type=int, default=1, help="repetitions")
    p.add_argument("-j", type=int, default=4, help="concurrent runs")
    args = p.parse_args()
    tasks = [t for t in tomllib.loads((EVAL / "tasks.toml").read_text())["task"] if not args.tasks or t["id"] in args.tasks]
    outdir = EVAL / "results" / time.strftime("%Y%m%d-%H%M%S")
    outdir.mkdir(parents=True)
    jobs = [(t, a, m, i) for i in range(args.n) for t in tasks for a in args.arms for m in args.models]
    rows = []
    with cf.ThreadPoolExecutor(args.j) as ex, open(outdir / "results.jsonl", "w") as f:
        for fut in cf.as_completed([ex.submit(run, *j, outdir) for j in jobs]):
            r = fut.result()
            rows.append(r)
            f.write(json.dumps(r) + "\n")
            f.flush()
            print(json.dumps(r), flush=True)
    print(f"\n{'arm':10} {'model':8} {'correct':>8} {'turns':>6} {'ctx tok':>9} {'out tok':>8} {'cost $':>7} {'sec':>5}")
    for a in args.arms:
        for m in args.models:
            rs = [r for r in rows if r["arm"] == a and r["model"] == m]
            med = lambda k: statistics.median(r[k] or 0 for r in rs)
            print(f"{a:10} {m:8} {sum(r['correct'] for r in rs):>4}/{len(rs):<3} {med('turns'):>6} {med('context_tokens'):>9.0f} "
                  f"{med('output_tokens'):>8.0f} {med('cost'):>7.2f} {med('seconds'):>5.0f}")
    print(f"\nmedians; logs in {outdir}")


if __name__ == "__main__":
    main()
