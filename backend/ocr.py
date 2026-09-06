#!/usr/bin/env python3
import sys
import os
import argparse
import csv
import io
import json
import subprocess

def get_available_languages(tessdata_dir):
    if not os.path.exists(tessdata_dir):
        return ["eng"]
    langs = []
    for f in os.listdir(tessdata_dir):
        if f.endswith(".traineddata") and not f.startswith("osd") and not f.startswith("pdf"):
            langs.append(f[:-12])
    return langs if langs else ["eng"]

def run_ocr(image_path, lang=None):
    if not os.path.exists(image_path):
        return {"status": "error", "message": f"Image file not found: {image_path}"}

    # Detect user-level or system-level tessdata
    user_tessdata = os.path.expanduser("~/.local/share/tessdata")
    env = os.environ.copy()
    if os.path.exists(user_tessdata):
        env["TESSDATA_PREFIX"] = user_tessdata
        tessdata_path = user_tessdata
    else:
        tessdata_path = "/usr/share/tessdata"

    def map_lang_code(code):
        mapping = {
            "en": "eng", "es": "spa", "fr": "fra", "de": "deu",
            "it": "ita", "pt": "por", "ru": "rus", "zh": "chi_sim",
            "zh-CN": "chi_sim", "ja": "jpn", "ko": "kor", "hi": "hin",
            "ta": "tam", "ar": "ara"
        }
        return mapping.get(code, code)

    # Determine languages to load
    if not lang or lang == "auto":
        # Fast Latin base (English, Spanish) for instant everyday OCR (~2s)
        lang_arg = "eng+spa"
    else:
        # Load user-requested language along with English base
        parsed_langs = [map_lang_code(l.strip()) for l in lang.split("+") if l.strip()]
        if "eng" not in parsed_langs:
            parsed_langs.insert(0, "eng")
        lang_arg = "+".join(parsed_langs)

    try:
        # Run tesseract with TSV output and multilingual LSTM models
        # Note: Options must precede configfile 'tsv'
        cmd = ["tesseract", image_path, "stdout", "-l", lang_arg, "--oem", "1", "--psm", "3", "tsv"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=True, env=env)
    except subprocess.CalledProcessError as e:
        return {"status": "error", "message": f"Tesseract failed: {e}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

    # Open image with PIL to sample background and text colors for Android-style inpainting
    img_rgb = None
    try:
        from PIL import Image
        import numpy as np
        raw_img = Image.open(image_path).convert("RGB")
        img_np = np.array(raw_img)
        img_h, img_w, _ = img_np.shape
    except Exception:
        img_np = None

    def sample_colors(x, y, w, h):
        if img_np is None or w <= 0 or h <= 0:
            return "#121212", "#ffffff"
        try:
            x1, y1 = max(0, int(x)), max(0, int(y))
            x2, y2 = min(img_w, int(x + w)), min(img_h, int(y + h))
            if x2 <= x1 or y2 <= y1:
                return "#121212", "#ffffff"

            crop = img_np[y1:y2, x1:x2]
            # Sample border perimeter pixels for accurate background color
            top_edge = crop[0, :, :]
            bottom_edge = crop[-1, :, :]
            left_edge = crop[:, 0, :]
            right_edge = crop[:, -1, :]
            perimeter = np.concatenate([top_edge, bottom_edge, left_edge, right_edge], axis=0)
            median_bg = np.median(perimeter, axis=0).astype(int)
            bg_hex = f"#{median_bg[0]:02x}{median_bg[1]:02x}{median_bg[2]:02x}"

            # Detect foreground text color via contrast against sampled background
            diffs = np.linalg.norm(crop - median_bg, axis=2)
            text_mask = diffs > 35
            if np.any(text_mask):
                median_text = np.median(crop[text_mask], axis=0).astype(int)
                text_hex = f"#{median_text[0]:02x}{median_text[1]:02x}{median_text[2]:02x}"
            else:
                lum = 0.299 * median_bg[0] + 0.587 * median_bg[1] + 0.114 * median_bg[2]
                text_hex = "#000000" if lum > 128 else "#ffffff"

            return bg_hex, text_hex
        except Exception:
            return "#121212", "#ffffff"

    reader = csv.DictReader(io.StringIO(proc.stdout), delimiter="\t")
    words = []
    lines = {}

    for row in reader:
        level = row.get("level")
        text = row.get("text", "").strip()
        try:
            left = int(row.get("left", 0))
            top = int(row.get("top", 0))
            width = int(row.get("width", 0))
            height = int(row.get("height", 0))
            conf = float(row.get("conf", -1))
        except (ValueError, TypeError):
            continue

        b = row.get("block_num", "0")
        p = row.get("par_num", "0")
        l = row.get("line_num", "0")
        line_id = f"{b}_{p}_{l}"

        if level == "4":  # Line level definition
            bg_col, text_col = sample_colors(left, top, width, height)
            lines[line_id] = {
                "id": line_id,
                "x": left,
                "y": top,
                "w": width,
                "h": height,
                "text": "",
                "bg_color": bg_col,
                "text_color": text_col,
                "words": []
            }
        elif level == "5" and text:  # Word level definition
            # Discard obvious OCR noise (single weird symbols with very low confidence)
            if conf < 15 and len(text) <= 1:
                continue

            bg_col, text_col = sample_colors(left, top, width, height)
            word_obj = {
                "text": text,
                "x": left,
                "y": top,
                "w": width,
                "h": height,
                "conf": conf,
                "bg_color": bg_col,
                "text_color": text_col,
                "line_id": line_id
            }
            words.append(word_obj)

            if line_id in lines:
                if lines[line_id]["text"]:
                    lines[line_id]["text"] += " " + text
                else:
                    lines[line_id]["text"] = text
                lines[line_id]["words"].append(word_obj)

    # Filter out empty lines
    valid_lines = [line for line in lines.values() if line["text"].strip()]

    return {
        "status": "ok",
        "words": words,
        "lines": valid_lines
    }

def main():
    parser = argparse.ArgumentParser(description="Nilastia OCR Service")
    parser.add_argument("--image", default="/tmp/cts-screen.png", help="Screenshot path")
    parser.add_argument("--output", default="/tmp/cts-ocr.json", help="Path to save output JSON")
    parser.add_argument("--lang", default="", help="Languages to recognize (e.g. eng+jpn+tam)")
    args = parser.parse_args()

    result = run_ocr(args.image, lang=args.lang if args.lang else None)
    if args.output:
        try:
            with open(args.output, "w") as f:
                json.dump(result, f)
        except Exception as e:
            sys.stderr.write(f"Failed to write output JSON: {e}\n")

    print(json.dumps(result))
    return 0 if result.get("status") == "ok" else 1

if __name__ == "__main__":
    sys.exit(main())

