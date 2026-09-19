"""Rewrite a floor layout JSON with one polygon per line for readable diffs."""

import json
import sys


def dump(value, indent=0):
    pad = "  " * indent
    if isinstance(value, dict):
        if all(not isinstance(v, (dict, list)) or _is_point_list(v) or _is_point(v)
               for v in value.values()) and indent >= 2:
            return "{" + ", ".join(f"{json.dumps(k)}: {dump(v, indent + 1)}"
                                   for k, v in value.items()) + "}"
        inner = ",\n".join(f"{pad}  {json.dumps(k)}: {dump(v, indent + 1)}" for k, v in value.items())
        return "{\n" + inner + "\n" + pad + "}"
    if isinstance(value, list):
        if _is_point(value) or _is_point_list(value) or not value:
            return json.dumps(value, separators=(", ", ": "))
        inner = ",\n".join(f"{pad}  {dump(v, indent + 1)}" for v in value)
        return "[\n" + inner + "\n" + pad + "]"
    return json.dumps(value)


def _is_point(value):
    return isinstance(value, list) and len(value) == 2 and all(
        isinstance(v, (int, float)) for v in value)


def _is_point_list(value):
    return isinstance(value, list) and value and all(_is_point(v) for v in value)


if __name__ == "__main__":
    for path in sys.argv[1:]:
        data = json.load(open(path, encoding="utf-8"))
        open(path, "w", encoding="utf-8", newline="\n").write(dump(data) + "\n")
