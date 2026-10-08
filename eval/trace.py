#!/usr/bin/env python3
"""Print the tool calls, results and replies of run transcripts, truncated: where the turns went."""

import json
import sys


def text(c):
    return c if isinstance(c, str) else " ".join(x.get("text", "") for x in c)


for path in sys.argv[1:]:
    print(f"=== {path}")
    for line in open(path):
        e = json.loads(line)
        content = e.get("message", {}).get("content", [])
        for c in content if isinstance(content, list) else []:
            if c.get("type") == "tool_use":
                print("CALL  ", json.dumps(c["input"])[:800])
            elif c.get("type") == "tool_result":
                print("RESULT", text(c["content"])[:500].replace("\n", " | "))
            elif c.get("type") == "text" and e["type"] == "assistant":
                print("REPLY ", c["text"][:300].replace("\n", " | "))
