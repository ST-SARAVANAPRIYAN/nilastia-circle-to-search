#!/usr/bin/env python3
import sys
import os
import argparse
import json
import subprocess

def translate_single(text, target_lang="en"):
    if not text.strip():
        return ""
    try:
        cmd = ["trans", "-brief", f":{target_lang}", text]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=True)
        return proc.stdout.strip()
    except Exception as e:
        sys.stderr.write(f"Translation error: {e}\n")
        return text

def translate_batch(items, target_lang="en"):
    """
    items: list of dicts with {"id": ..., "text": ...}
    Translates all items in a single piped trans call to preserve speed and avoid rate limits.
    """
    if not items:
        return []

    # Filter out empty or pure punctuation/numeric lines that don't need network translation
    to_translate = {}
    for item in items:
        raw_text = item.get("text", "").replace("\n", " ").strip()
        # If text has no alphabetical characters or is very short symbols, skip network translation
        has_alpha = any(c.isalpha() for c in raw_text)
        if raw_text and has_alpha and len(raw_text) > 1:
            if raw_text not in to_translate:
                to_translate[raw_text] = None

    if to_translate:
        unique_texts = list(to_translate.keys())
        payload = "\n".join(unique_texts)
        try:
            cmd = ["trans", "-brief", f":{target_lang}"]
            proc = subprocess.run(cmd, input=payload, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=True, timeout=12)
            translated_lines = proc.stdout.strip().split("\n")
            for i, utext in enumerate(unique_texts):
                if i < len(translated_lines) and translated_lines[i].strip():
                    to_translate[utext] = translated_lines[i].strip()
                else:
                    to_translate[utext] = utext
        except Exception as e:
            sys.stderr.write(f"Batch translation error: {e}\n")
            for utext in unique_texts:
                to_translate[utext] = utext

    results = []
    for item in items:
        raw_text = item.get("text", "").replace("\n", " ").strip()
        translated_text = to_translate.get(raw_text, raw_text)
        # Only include if there is actual content
        if raw_text:
            results.append({
                "id": item.get("id"),
                "original": raw_text,
                "translated": translated_text,
                "x": item.get("x", 0),
                "y": item.get("y", 0),
                "w": item.get("w", 0),
                "h": item.get("h", 0),
                "bg_color": item.get("bg_color", "#121212"),
                "text_color": item.get("text_color", "#ffffff")
            })
    return results

def main():
    parser = argparse.ArgumentParser(description="Nilastia Translation Service")
    parser.add_argument("--mode", choices=["single", "batch"], default="single")
    parser.add_argument("--text", default="", help="Single text to translate")
    parser.add_argument("--target", default="en", help="Target language code (e.g. en, es, ta, fr)")
    parser.add_argument("--batch-file", default="", help="Path to JSON file containing lines to translate")
    args = parser.parse_args()

    if args.mode == "single":
        translated = translate_single(args.text, args.target)
        print(json.dumps({"status": "ok", "original": args.text, "translated": translated, "target": args.target}))
        return 0
    else:
        # Batch mode
        items = []
        if args.batch_file and os.path.exists(args.batch_file):
            with open(args.batch_file, "r") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict) and "lines" in loaded:
                    items = loaded["lines"]
                elif isinstance(loaded, list):
                    items = loaded
                else:
                    items = []
        else:
            # Read from stdin
            raw = sys.stdin.read()
            if raw.strip():
                loaded = json.loads(raw)
                if isinstance(loaded, dict) and "lines" in loaded:
                    items = loaded["lines"]
                elif isinstance(loaded, list):
                    items = loaded
                else:
                    items = []

        results = translate_batch(items, args.target)
        print(json.dumps({"status": "ok", "results": results, "target": args.target}))
        return 0

if __name__ == "__main__":
    sys.exit(main())
