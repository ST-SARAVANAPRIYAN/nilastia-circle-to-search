#!/usr/bin/env python3
import sys
import os
import re
import shutil
import argparse
import json
import subprocess
import urllib.request
import urllib.error
import uuid

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def http_error_303(self, req, fp, code, msg, headers):
        return fp
    def http_error_302(self, req, fp, code, msg, headers):
        return fp

def crop_image(src_path, dst_path, x, y, w, h):
    try:
        crop_arg = f"{int(w)}x{int(h)}+{int(x)}+{int(y)}"
        subprocess.run(["magick", src_path, "-crop", crop_arg, "+repage", dst_path], check=True, capture_output=True)
        return True
    except Exception as e:
        sys.stderr.write(f"Crop error: {e}\n")
        return False

import base64

def generate_lens_html(img_path):
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"Image not found: {img_path}")

    with open(img_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")

    html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Google Lens - Circle to Search</title>
  <style>
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: #121212;
      color: #e3e3e3;
      font-family: system-ui, -apple-system, Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      overflow: hidden;
    }}
    .spinner {{
      width: 36px;
      height: 36px;
      border: 3px solid rgba(255,255,255,0.1);
      border-top-color: #8ab4f8;
      border-radius: 50%;
      animation: spin 0.75s linear infinite;
      margin-bottom: 18px;
    }}
    @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
    .title {{ font-size: 15px; font-weight: 500; letter-spacing: 0.2px; color: #e8eaed; }}
    .sub {{ font-size: 12px; color: #9aa0a6; margin-top: 6px; }}
  </style>
</head>
<body>
  <div class="spinner"></div>
  <div class="title">Searching with Google Lens...</div>
  <div class="sub">Uploading selection</div>
  <form id="lensForm" action="https://lens.google.com/upload?ep=subb&hl=en" method="POST" enctype="multipart/form-data" style="display:none;">
    <input type="file" name="encoded_image" id="fileInput">
  </form>
  <script>
    try {{
      const b64 = "{b64}";
      const binary = atob(b64);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) {{
        bytes[i] = binary.charCodeAt(i);
      }}
      const file = new File([bytes], "selection.png", {{ type: "image/png" }});
      const dt = new DataTransfer();
      dt.items.add(file);
      const input = document.getElementById("fileInput");
      input.files = dt.files;
      document.getElementById("lensForm").submit();
    }} catch (err) {{
      document.body.innerHTML = "<div style='color:#f28b82;padding:24px;'>Error launching Lens: " + err.message + "</div>";
    }}
  </script>
</body>
</html>"""

    html_path = "/tmp/cts-lens.html"
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    return html_path

def copy_to_clipboard(path):
    try:
        with open(path, "rb") as f:
            subprocess.run(["wl-copy", "--type", "image/png"], input=f.read(), check=True)
    except Exception as e:
        sys.stderr.write(f"wl-copy image error: {e}\n")

def resolve_browser(preferred="auto"):
    # If the user explicitly configured a specific browser:
    if preferred and preferred.strip().lower() != "auto":
        bin_name = preferred.strip()
        bin_path = shutil.which(bin_name)
        if bin_path:
            name = os.path.basename(bin_path).lower()
            if any(c in name for c in ["brave", "chrome", "chromium", "vivaldi", "edge", "opera"]):
                return bin_path, "chromium"
            elif any(f in name for f in ["firefox", "zen", "librewolf", "waterfox", "floorp"]):
                return bin_path, "firefox"
            return bin_path, "generic"
        sys.stderr.write(f"Configured browser '{preferred}' not found in PATH, falling back to auto-detection\n")

    # 1. Chromium-based browsers supporting native --app= frameless mode
    chromium_bins = [
        "brave",
        "google-chrome-stable",
        "google-chrome",
        "chromium",
        "chromium-browser",
        "vivaldi",
        "microsoft-edge-stable",
        "microsoft-edge",
        "opera",
    ]
    for b in chromium_bins:
        bin_path = shutil.which(b)
        if bin_path:
            return bin_path, "chromium"

    # 2. Gecko/Firefox-based browsers supporting --new-window
    firefox_bins = [
        "zen-browser",
        "zen",
        "firefox",
        "firefox-developer-edition",
        "librewolf",
        "waterfox",
        "floorp",
    ]
    for b in firefox_bins:
        bin_path = shutil.which(b)
        if bin_path:
            return bin_path, "firefox"

    # 3. Desktop generic handler via xdg-open
    if shutil.which("xdg-open"):
        return "xdg-open", "generic"

    return None, None

def main():
    parser = argparse.ArgumentParser(description="Nilastia Google Lens Upload Service")
    parser.add_argument("--image", default="/tmp/cts-screen.png", help="Path to input image")
    parser.add_argument("--crop", default="", help="Crop box: x,y,w,h")
    parser.add_argument("--browser", default="auto", help="Browser binary to launch (default: auto)")
    parser.add_argument("--no-launch", action="store_true", help="Do not launch browser, only return URL")

    args = parser.parse_args()

    target_img = args.image
    if args.crop:
        try:
            parts = [int(float(p)) for p in args.crop.split(",")]
            if len(parts) == 4 and parts[2] > 10 and parts[3] > 10:
                crop_path = "/tmp/cts-crop.png"
                if crop_image(args.image, crop_path, parts[0], parts[1], parts[2], parts[3]):
                    target_img = crop_path
        except Exception as e:
            sys.stderr.write(f"Failed to parse crop: {e}\n")

    # Also stage image to clipboard for instantaneous manual paste if desired
    copy_to_clipboard(target_img)

    try:
        html_path = generate_lens_html(target_img)
        target_url = f"file://{html_path}"

        if not args.no_launch:
            browser_bin, browser_type = resolve_browser(args.browser)
            if not browser_bin:
                subprocess.run([
                    "notify-send",
                    "-a", "Circle to Search",
                    "-i", "travel_explore",
                    "Circle to Search",
                    "Selection copied to clipboard. No web browser found on system."
                ])
                print(json.dumps({
                    "status": "no_browser",
                    "message": "Selection copied to clipboard. No web browser found on system.",
                    "url": target_url,
                    "html": html_path,
                    "clipboard": True
                }))
                return 0

            if browser_type == "chromium":
                subprocess.Popen([browser_bin, f"--app={target_url}", "--window-size=640,980"])
            elif browser_type == "firefox":
                subprocess.Popen([browser_bin, "--new-window", target_url])
            else:
                subprocess.Popen([browser_bin, target_url])

            print(json.dumps({
                "status": "ok",
                "url": target_url,
                "html": html_path,
                "browser": browser_bin,
                "type": browser_type
            }))
            return 0
        else:
            print(json.dumps({"status": "ok", "url": target_url, "html": html_path}))
            return 0
    except Exception as e:
        sys.stderr.write(f"Lens error: {e}\n")
        print(json.dumps({"status": "error", "message": str(e)}))
        return 1

if __name__ == "__main__":
    sys.exit(main())
